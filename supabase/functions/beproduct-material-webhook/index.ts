// BeProduct Material Webhook Handler for Supabase
// TEMPORARY: Authentication disabled for testing
// Enhanced: Supports dynamic schema changes (auto-creates missing columns)
import "https://deno.land/std@0.168.0/dotenv/load.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function getField(obj: any, key: string) {
  return obj?.[key]?.value ?? null;
}

// Infer SQL type from value
function inferSqlType(value: any): string {
  if (value === null || value === undefined) return "TEXT";
  if (typeof value === "boolean") return "BOOLEAN";
  if (typeof value === "number") {
    if (Number.isInteger(value)) return "INTEGER";
    return "NUMERIC";
  }
  if (typeof value === "object") return "JSONB";
  return "TEXT";
}

// Extract all fields from payload recursively
function extractAllFields(obj: any, prefix = ""): Record<string, any> {
  const fields: Record<string, any> = {};
  if (!obj || typeof obj !== "object") return fields;
  for (const [key, val] of Object.entries(obj)) {
    if (val === null || val === undefined) continue;
    if (typeof val === "object" && (val as any).value !== undefined) {
      // Handle BeProduct field structure
      fields[key] = (val as any).value;
    } else if (typeof val === "object" && !Array.isArray(val)) {
      // Skip complex nested objects (colorways, sizeRange, suppliers, etc.)
      if (
        ![
          "colorways",
          "sizeRange",
          "suppliers",
          "tags",
          "planIds",
          "mainImage",
          "detailImage",
          "createdBy",
          "modifiedBy",
          "composition",
          "back_content",
          "care_instructions",
        ].includes(key)
      ) {
        Object.assign(fields, extractAllFields(val, `${prefix}${key}_`));
      }
    } else if (!Array.isArray(val)) {
      fields[key] = val;
    }
  }
  return fields;
}

// Sanitize column names to be SQL-safe
function sanitizeColumnName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+/, "")
    .replace(/_+$/, "");
}

// Get existing columns in a table via direct SQL execution
async function getExistingColumns(supabase: any, schema: string, tableName: string): Promise<Set<string>> {
  try {
    const { data, error } = await supabase.rpc("get_table_columns", {
      p_schema: schema,
      p_table: tableName,
    });
    if (error) {
      console.warn("Error fetching columns, using fallback:", error.message);
      // Fallback: return empty set to try adding columns anyway
      return new Set();
    }
    return new Set((data || []).map((col: any) => col.column_name));
  } catch (error) {
    console.warn("Exception fetching columns, using fallback:", error);
    return new Set();
  }
}

// Create missing columns via exec_sql RPC
async function ensureColumns(supabase: any, schema: string, tableName: string, fields: Record<string, any>) {
  const existingColumns = await getExistingColumns(supabase, schema, tableName);
  const missingColumns: Array<{ name: string; type: string }> = [];

  for (const colName of Object.keys(fields)) {
    const safeColName = sanitizeColumnName(colName);
    if (!existingColumns.has(safeColName)) {
      const colType = inferSqlType(fields[colName]);
      missingColumns.push({ name: safeColName, type: colType });
    }
  }

  if (missingColumns.length === 0) {
    console.log(`No new columns needed for ${schema}.${tableName}`);
    return fields; // No new columns needed
  }

  // Execute ALTER TABLE statements
  console.log(`Adding ${missingColumns.length} new columns to ${schema}.${tableName}`);
  for (const col of missingColumns) {
    const alterSql = `ALTER TABLE ${schema}.${tableName} ADD COLUMN IF NOT EXISTS ${col.name} ${col.type};`;
    console.log("Executing:", alterSql);
    try {
      const { error } = await supabase.rpc("exec_sql", { sql: alterSql });
      if (error) {
        console.warn(`Warning: Column ${col.name} may not have been created:`, error.message);
      } else {
        console.log(`Added column ${col.name} (${col.type})`);
      }
    } catch (error) {
      console.warn(`Exception adding column ${col.name}:`, error);
      // Continue anyway - the INSERT might still work
    }
  }

  // Rename fields to match safe column names
  const safeFields: Record<string, any> = {};
  for (const colName of Object.keys(fields)) {
    const safeColName = sanitizeColumnName(colName);
    safeFields[safeColName] = fields[colName];
  }
  return safeFields;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let payload;
  try {
    payload = await req.json();
    console.log("Received payload:", JSON.stringify(payload));
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const eventType = payload.eventType;
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Handle OnDelete event
  if (eventType === "OnDelete") {
    const materialId = payload.headerId;
    if (!materialId) {
      return new Response(JSON.stringify({ ok: false, error: "Missing headerId for deletion" }), { status: 400 });
    }
    try {
      const { error: materialError } = await supabase
        .schema("pim")
        .from("material")
        .update({ deleted: true, raw_beproduct_data: payload, beproduct_modified_at: new Date().toISOString() })
        .eq("beproduct_material_id", materialId);
      if (materialError) {
        console.error("Material deletion error:", materialError);
        return new Response(JSON.stringify({ ok: false, error: materialError.message }), { status: 500 });
      }
      console.log("Material soft-deleted:", materialId);
      return new Response(JSON.stringify({ ok: true, action: "deleted", materialId }), { status: 200 });
    } catch (error) {
      console.error("Delete processing error:", error);
      return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
    }
  }

  // Handle OnChange, OnCopy, OnCreate events
  if (!["OnChange", "OnCopy", "OnCreate"].includes(eventType)) {
    return new Response(JSON.stringify({ ok: false, error: "Unsupported eventType" }), { status: 200 });
  }

  const after = payload.data?.after;
  if (!after) {
    return new Response(JSON.stringify({ ok: false, error: "No after data" }), { status: 200 });
  }

  const before = payload.data?.before;

  console.log("=== Processing payload ===");
  console.log(`Colorways: ${(after.colorways || []).length}`);
  console.log(`SizeRange: ${(after.sizeRange || []).length}`);
  console.log(`Suppliers: ${(after.suppliers || []).length}`);
  console.log(`Tags: ${after.tags ? (Array.isArray(after.tags) ? after.tags.length : 1) : 0}`);
  console.log(`PlanIds: ${(after.planIds || []).length}`);

  try {
    const materialId = payload.headerId;
    const headerNumber = getField(after, "header_number") ?? payload.headerNumber;
    const headerName = getField(after, "header_name") ?? payload.headerName;
    if (!headerNumber || !headerName) {
      console.error("Missing required fields:", { headerNumber, headerName });
      return new Response(JSON.stringify({ ok: false, error: "Missing required fields: header_number or header_name" }), { status: 400 });
    }

    // Define base material fields - only include fields that exist in the schema
    const materialData: Record<string, any> = {
      beproduct_material_id: materialId,
      header_number: headerNumber,
      header_name: headerName,
      beproduct_folder_id: payload.folderId,
      folder_name: payload.folderName,
      brand: getField(after, "brand_1"),
      material_type: getField(after, "material_type"),
      fabric_group: getField(after, "fabric_group"),
      fabric_name_cn: getField(after, "fabric_name_cn"),
      status: getField(after, "status"),
      season_year: getField(after, "season_year"),
      composition: getField(after, "composition"),
      back_content: getField(after, "back_content"),
      care_instructions: getField(after, "care_instructions"),
      properties_fabric: getField(after, "properties_fabric"),
      supplier: getField(after, "supplier"),
      supplier_code: getField(after, "supplier_code"),
      material_reference_code: getField(after, "material_reference_code"),
      lead_time: getField(after, "lead_time") ?? getField(after, "leadtime"),
      material_width: getField(after, "material_width"),
      material_full_width: getField(after, "material_full_width"),
      material_weight: getField(after, "material_weight"),
      unit_of_measure_base: getField(after, "unit_of_measure_base"),
      material_purchase_price: getField(after, "material_purchase_price"),
      currency_lookup: getField(after, "currency_lookup"),
      unit_of_measure_purchase_price: getField(after, "unit_of_measure_purchase_price"),
      costing_price_usd: getField(after, "costing_price_usd"),
      material_yield: getField(after, "material_yield"),
      material_moq: getField(after, "material_moq"),
      material_mcq: getField(after, "material_mcq"),
      surcharge_moq: getField(after, "surcharge_moq"),
      surcharge_mcq: getField(after, "surcharge_mcq"),
      core_3d_material: getField(after, "core_3d_material"),
      main_image_preview: after.mainImage?.preview,
      main_image_url: after.mainImage?.origin,
      detail_image_preview: after.detailImage?.preview,
      detail_image_url: after.detailImage?.origin,
      notes: getField(after, "notes"),
      created_by: after.createdBy?.name ?? getField(after, "created_by"),
      beproduct_created_at: after.createdAt,
      modified_by: after.modifiedBy?.name ?? getField(after, "modified_by"),
      beproduct_modified_at: after.modifiedAt,
      deleted: after.isDeleted ?? false,
      raw_beproduct_data: after
    };

    // Filter out null values to prevent upsert errors
    const cleanedData = Object.fromEntries(
      Object.entries(materialData).filter(([_, value]) => value !== null && value !== undefined)
    );

    console.log(`Upserting material with ${Object.keys(cleanedData).length} fields`);

    // Upsert material
    const { data: materialRow, error: materialError } = await supabase
      .schema("pim")
      .from("material")
      .upsert(cleanedData, { onConflict: "beproduct_material_id" })
      .select()
      .single();
    if (materialError) {
      console.error("Material upsert error:", materialError);
      return new Response(JSON.stringify({ ok: false, error: materialError.message }), { status: 500 });
    }

    // Upsert related entities
    const materialRowId = materialRow?.id;
    if (!materialRowId) {
      return new Response(JSON.stringify({ ok: false, error: "Material row ID not found after upsert" }), { status: 500 });
    }

    // Helper to sync related rows using before/after comparison
    // This approach compares the before and after states to determine true deletes
    async function syncRelatedWithBeforeAfter(
      table: string,
      rows: any[],
      beforeRows: any[] | undefined,
      uniqueKey: string = "id"
    ) {
      // Ensure table has all required columns (dynamic schema update)
      if (rows && rows.length > 0) {
        const sample = rows[0];
        if (sample) {
          console.log(`Ensuring ${table} table has all columns...`);
          const allFields: Record<string, any> = { material_id: materialRowId };
          for (const row of rows) {
            Object.assign(allFields, row);
          }
          await ensureColumns(supabase, "pim", table, allFields);
        }
      }

      // Get IDs from new and old data
      const incomingIds = (rows || []).map((r: any) => r[uniqueKey]).filter((id: any) => id);
      const beforeIds = (beforeRows || []).map((r: any) => r[uniqueKey]).filter((id: any) => id);
      const deletedIds = beforeIds.filter((id: any) => !incomingIds.includes(id));

      // Delete rows that were in 'before' but not in 'after'
      if (deletedIds.length > 0) {
        const { error: deleteError } = await supabase
          .schema("pim")
          .from(table)
          .delete()
          .eq("material_id", materialRowId)
          .in(uniqueKey, deletedIds);
        if (deleteError) {
          console.error(`Delete error for ${table}:`, deleteError.message);
        } else {
          console.log(`Deleted ${deletedIds.length} removed rows from ${table}`);
        }
      }

      // Upsert current rows
      if (rows && rows.length > 0) {
        const { data, error } = await supabase
          .schema("pim")
          .from(table)
          .upsert(rows, { onConflict: `material_id,${uniqueKey}` });
        if (error) {
          console.error(`Upsert error for ${table}:`, error.message);
        } else {
          console.log(`Upserted ${rows.length} rows in ${table}`);
        }
      } else if (rows && rows.length === 0 && beforeIds.length > 0) {
        // Empty array in 'after' = delete all
        console.log(`Empty array for ${table}, deleting all existing rows for this material`);
        await supabase.schema("pim").from(table).delete().eq("material_id", materialRowId);
      }
    }

    // Colorways - Extract all fields from each colorway for dynamic schema support
    const colorways = after.colorways || [];
    console.log(`Found ${colorways.length} colorways in payload`);
    const colorwayRows = colorways.map((c: any) => {
      let colorwayData: Record<string, any> = {
        material_id: materialRowId,
        colorway_id: c.id,
        name: c.colorName,
        code: c.colorNumber,
        hex: c.primaryColor || null
      };

      // Extract additional fields from colorway object
      if (c.fields) {
        for (const [key, value] of Object.entries(c.fields)) {
          const safeKey = sanitizeColumnName(key);
          if (!(safeKey in colorwayData) && value !== null && value !== undefined) {
            colorwayData[safeKey] = value;
          }
        }
      }

      // Add other colorway properties
      if (c.comments) colorwayData["comments"] = c.comments;
      if (c.image) colorwayData["image"] = c.image;
      if (c.hideColorway !== undefined) colorwayData["hide_colorway"] = c.hideColorway;
      if (c.primaryColor) colorwayData["primary_color"] = c.primaryColor;
      if (c.secondaryColor) colorwayData["secondary_color"] = c.secondaryColor;
      if (c.secondaryColorName) colorwayData["secondary_color_name"] = c.secondaryColorName;
      if (c.secondaryColorNumber) colorwayData["secondary_color_number"] = c.secondaryColorNumber;
      if (c.colorSourceId) colorwayData["color_source_id"] = c.colorSourceId;
      if (c.imageHeaderId) colorwayData["image_header_id"] = c.imageHeaderId;

      return colorwayData;
    });
    console.log(`Extracted ${colorwayRows.length} colorway rows`);
    await syncRelatedWithBeforeAfter("material_colorway", colorwayRows, before?.colorways, "colorway_id");

    // Size Ranges - Extract all fields for dynamic schema support
    const sizeRanges = after.sizeRange || [];
    console.log(`Found ${sizeRanges.length} size ranges in payload`);
    const sizeRangeRows = sizeRanges.map((s: any) => {
      let sizeRangeData: Record<string, any> = {
        material_id: materialRowId,
        size_range_id: s.name,
        name: s.name,
        sizes: JSON.stringify(s)
      };

      // Extract additional fields from sizeRange object
      if (s.fields) {
        for (const [key, value] of Object.entries(s.fields)) {
          const safeKey = sanitizeColumnName(key);
          if (!(safeKey in sizeRangeData) && value !== null && value !== undefined) {
            sizeRangeData[safeKey] = value;
          }
        }
      }

      return sizeRangeData;
    });
    console.log(`Extracted ${sizeRangeRows.length} size range rows`);
    await syncRelatedWithBeforeAfter("material_size_range", sizeRangeRows, before?.sizeRange, "size_range_id");

    // Suppliers - Extract all fields for dynamic schema support
    const suppliers = after.suppliers || [];
    console.log(`Found ${suppliers.length} suppliers in payload`);
    const supplierRows = suppliers.map((s: any) => {
      let supplierData: Record<string, any> = {
        material_id: materialRowId,
        supplier_id: s.id || s.code || s.value,
        name: s.name || s.value,
        code: s.code,
        is_primary: s.isPrimary || false
      };

      // Extract additional fields from supplier object
      if (s.fields) {
        for (const [key, value] of Object.entries(s.fields)) {
          const safeKey = sanitizeColumnName(key);
          if (!(safeKey in supplierData) && value !== null && value !== undefined) {
            supplierData[safeKey] = value;
          }
        }
      }

      return supplierData;
    });
    console.log(`Extracted ${supplierRows.length} supplier rows`);
    await syncRelatedWithBeforeAfter("material_supplier", supplierRows, before?.suppliers, "supplier_id");

    // Tags - Extract all fields for dynamic schema support
    const tags = after.tags || [];
    console.log(`Found ${tags.length} tags in payload`);
    const tagRows = Array.isArray(tags)
      ? tags.map((t: any) => {
          let tagData: Record<string, any> = {
            material_id: materialRowId,
            tag: t
          };

          // Extract additional fields if tag is an object
          if (typeof t === "object" && t !== null) {
            if (t.fields) {
              for (const [key, value] of Object.entries(t.fields)) {
                const safeKey = sanitizeColumnName(key);
                if (!(safeKey in tagData) && value !== null && value !== undefined) {
                  tagData[safeKey] = value;
                }
              }
            }
            if (t.name) tagData["name"] = t.name;
            if (t.value) tagData["tag"] = t.value;
          }

          return tagData;
        })
      : [];
    console.log(`Extracted ${tagRows.length} tag rows`);
    await syncRelatedWithBeforeAfter("material_tag", tagRows, before?.tags, "tag");

    // Plan Links - Extract all fields for dynamic schema support
    const planIds = after.planIds || [];
    console.log(`Found ${planIds.length} plan links in payload`);
    const planRows = Array.isArray(planIds)
      ? planIds.map((p: any) => {
          let planData: Record<string, any> = {
            material_id: materialRowId,
            plan_id: p
          };

          // Extract additional fields if plan is an object
          if (typeof p === "object" && p !== null) {
            if (p.fields) {
              for (const [key, value] of Object.entries(p.fields)) {
                const safeKey = sanitizeColumnName(key);
                if (!(safeKey in planData) && value !== null && value !== undefined) {
                  planData[safeKey] = value;
                }
              }
            }
            if (p.id) planData["plan_id"] = p.id;
          }

          return planData;
        })
      : [];
    console.log(`Extracted ${planRows.length} plan link rows`);
    await syncRelatedWithBeforeAfter("material_plan_link", planRows, before?.planIds, "plan_id");

    return new Response(JSON.stringify({ ok: true, materialId }), { status: 200 });
  } catch (error) {
    console.error("Webhook processing error:", error);
    return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
  }
});
