// BeProduct Webhook Handler for Supabase
// TEMPORARY: Authentication disabled for testing
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";


function getField(obj: any, key: string) {
  return obj?.[key]?.value ?? null;
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
    const styleId = payload.headerId;
    if (!styleId) {
      return new Response(JSON.stringify({ ok: false, error: "Missing headerId for deletion" }), { status: 400 });
    }

    try {
      // Soft delete the style and update raw_beproduct_data
      const { error: styleError } = await supabase
        .schema("pim")
        .from("style")
        .update({ deleted: true, raw_beproduct_data: payload, beproduct_modified_at: new Date().toISOString() })
        .eq("beproduct_style_id", styleId);
      if (styleError) {
        console.error("Style deletion error:", styleError);
        return new Response(JSON.stringify({ ok: false, error: styleError.message }), { status: 500 });
      }

      // Soft delete all colorways for this style
      const { error: colorwayError } = await supabase
        .schema("pim")
        .from("style_colorway")
        .update({ deleted: true, raw_beproduct_data: payload, beproduct_modified_at: new Date().toISOString() })
        .eq("style_id",
          (await supabase.schema("pim").from("style").select("id").eq("beproduct_style_id", styleId).single()).data?.id
        );
      if (colorwayError) {
        console.error("Colorway deletion error:", colorwayError);
        // Continue, but log
      }

      // Soft delete all size classes for this style
      const { error: sizeClassError } = await supabase
        .schema("pim")
        .from("style_size_class")
        .update({ deleted: true, raw_beproduct_data: payload, beproduct_modified_at: new Date().toISOString() })
        .eq("style_id", (await supabase.schema("pim").from("style").select("id").eq("beproduct_style_id", styleId).single()).data?.id);
      if (sizeClassError) {
        console.error("Size class deletion error:", sizeClassError);
      }

      console.log("Style and related records soft-deleted:", styleId);
      return new Response(JSON.stringify({ ok: true, action: "deleted", styleId }), { status: 200 });
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

  try {
    // 1. Upsert style
    const styleId = payload.headerId;
    const headerNumber = getField(after, "header_number") ?? payload.headerNumber;
    const headerName = getField(after, "header_name") ?? payload.headerName;
    
    if (!headerNumber || !headerName) {
      console.error("Missing required fields:", { headerNumber, headerName });
      return new Response(JSON.stringify({ ok: false, error: "Missing required fields: header_number or header_name" }), { status: 400 });
    }
    
    const styleData = {
      beproduct_style_id: styleId,
      header_number: headerNumber,
      header_name: headerName,
      beproduct_folder_id: payload.folderId,
      folder_name: payload.folderName,
      version: getField(after, "version"),
      brand: getField(after, "brand_1"),
      product_type: getField(after, "product_type"),
      product_category: getField(after, "product_category"),
      delivery: getField(after, "delivery"),
      gender: getField(after, "gender"),
      season: getField(after, "season"),
      year: getField(after, "year"),
      season_year: getField(after, "season_year"),
      fabric_group: getField(after, "fabric_group"),
      classification: getField(after, "classification"),
      status: getField(after, "status"),
      account_manager: getField(after, "account_manager"),
      senior_product_developer: getField(after, "senior_product_developer"),
      core_size_range: getField(after, "core_size_range"),
      core_main_material: getField(after, "core_main_material"),
      front_image_preview: after.frontImage?.preview,
      front_image_url: after.frontImage?.origin,
      created_by: after.createdBy?.name ?? getField(after, "created_by"),
      beproduct_created_at: after.createdAt,
      modified_by: after.modifiedBy?.name ?? getField(after, "modified_by"),
      beproduct_modified_at: after.modifiedAt,
      deleted: after.deleted ?? false,
      raw_beproduct_data: after
    };
    const { data: styleRow, error: styleError } = await supabase.schema("pim").from("style").upsert(styleData, { onConflict: "beproduct_style_id" }).select().single();
    if (styleError) {
      console.error("Style upsert error:", styleError);
      return new Response(JSON.stringify({ ok: false, error: styleError.message }), { status: 500 });
    }
    const style_db_id = styleRow?.id;

    // 2. Upsert colorways and remove orphaned ones ONLY if colorways is present in payload
    let colorways = [];
    if (Array.isArray(after.colorways)) {
      colorways = after.colorways;
      const incomingColorwayIds = colorways.map(cw => cw.id).filter(id => id);
      for (const cw of colorways) {
        const fields = cw.fields || {};
        const colorwayData = {
          beproduct_colorway_id: cw.id,
          style_id: style_db_id,
          color_number: cw.colorNumber,
          color_name: cw.colorName,
          primary_hex: cw.primaryColor,
          secondary_hex: cw.secondaryColor,
          secondary_color_number: cw.secondaryColorNumber,
          secondary_color_name: cw.secondaryColorName,
          comments: cw.comments,
          hide_colorway: cw.hideColorway,
          image_header_id: cw.imageHeaderId,
          color_source_id: cw.colorSourceId,
          brand_marketing_name: fields.marketing_name,
          color_reference: fields.color_reference,
          color_number_ls: fields.color_number_ls,
          bulk_order_qty: fields.bulk_order_qty ?? null,
          core_colorway_main_material: fields.core_colorway_main_material ?? null,
          marketing_name: fields.marketing_name ?? null,
          raw_beproduct_data: cw
        };
        const { error: colorwayError } = await supabase.schema("pim").from("style_colorway").upsert(colorwayData, { onConflict: "beproduct_colorway_id,style_id" });
        if (colorwayError) {
          console.error("Colorway upsert error:", colorwayError);
        }
      }
      // Only delete colorways that were present in 'before' but missing in 'after'
      const beforeColorways = Array.isArray(payload.data?.before?.colorways) ? payload.data.before.colorways : [];
      const beforeColorwayIds = beforeColorways.map(cw => cw.id).filter(id => id);
      const deletedColorwayIds = beforeColorwayIds.filter(id => !incomingColorwayIds.includes(id));
      if (deletedColorwayIds.length > 0) {
        const { error: deleteColorwaysError } = await supabase
          .schema("pim")
          .from("style_colorway")
          .delete()
          .eq("style_id", style_db_id)
          .in("beproduct_colorway_id", deletedColorwayIds);
        if (deleteColorwaysError) {
          console.error("Colorway deletion error:", deleteColorwaysError);
        }
      }
    }

    // 3. Upsert size classes and remove orphaned ones ONLY if sizeClasses is present in payload
    let sizeClasses = [];
    if (Array.isArray(after.sizeClasses)) {
      sizeClasses = after.sizeClasses;
      const incomingSizeClassNames = sizeClasses.map(sc => sc.name).filter(name => name);
      for (const sc of sizeClasses) {
        const sizeClassData = {
          beproduct_size_class_id: sc.id ?? null,
          style_id: style_db_id,
          size_class_name: sc.name,
          is_default: sc.isDefault,
          sizes: sc.sizeRange ? JSON.stringify(sc.sizeRange) : null,
          raw_beproduct_data: sc,
          size_class_fields: sc.fields ?? null
        };
        const { error: sizeClassError } = await supabase.schema("pim").from("style_size_class").upsert(sizeClassData, { onConflict: "style_id,size_class_name" });
        if (sizeClassError) {
          console.error("Size class upsert error:", sizeClassError);
        }
      }
      // Only delete size classes that were present in 'before' but missing in 'after'
      const beforeSizeClasses = Array.isArray(payload.data?.before?.sizeClasses) ? payload.data.before.sizeClasses : [];
      const beforeSizeClassNames = beforeSizeClasses.map(sc => sc.name).filter(name => name);
      const deletedSizeClassNames = beforeSizeClassNames.filter(name => !incomingSizeClassNames.includes(name));
      if (deletedSizeClassNames.length > 0) {
        const { error: deleteSizeClassesError } = await supabase
          .schema("pim")
          .from("style_size_class")
          .delete()
          .eq("style_id", style_db_id)
          .in("size_class_name", deletedSizeClassNames);
        if (deleteSizeClassesError) {
          console.error("Size class deletion error:", deleteSizeClassesError);
        }
      }
    }

    return new Response(JSON.stringify({ ok: true, styleId, colorwaysCount: colorways.length, sizeClassesCount: sizeClasses.length }), { status: 200 });
  } catch (error) {
    console.error("Webhook processing error:", error);
    return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
  }
});
