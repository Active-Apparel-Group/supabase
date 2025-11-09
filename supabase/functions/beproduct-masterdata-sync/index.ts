/// <reference types="https://deno.land/x/deno/cli/tsc/dts/lib.deno.d.ts" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// @ts-ignore: Deno is available in the Edge Runtime environment
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// @ts-ignore: Deno is available in the Edge Runtime environment
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// @ts-ignore: Deno is available in the Edge Runtime environment
const BEPRODUCT_CLIENT_ID = Deno.env.get("BEPRODUCT_CLIENT_ID")!;
// @ts-ignore: Deno is available in the Edge Runtime environment
const BEPRODUCT_CLIENT_SECRET = Deno.env.get("BEPRODUCT_CLIENT_SECRET")!;
// @ts-ignore: Deno is available in the Edge Runtime environment
const BEPRODUCT_REFRESH_TOKEN = Deno.env.get("BEPRODUCT_REFRESH_TOKEN");
// @ts-ignore: Deno is available in the Edge Runtime environment
const BEPRODUCT_BASE_URL = Deno.env.get("BEPRODUCT_BASE_URL") || "https://developers.beproduct.com";
// @ts-ignore: Deno is available in the Edge Runtime environment
const BEPRODUCT_COMPANY = Deno.env.get("BEPRODUCT_COMPANY")!;

const FIELDS = [
  "product_type",
  "delivery",
  "gender",
  "product_category",
  "year",
  "season",
  "fabric_group",
  "classification",
  "status",
  "account_manager",
  "senior_product_developer",
  "color_number_ls",
];

interface BeProductTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
  refresh_token?: string;
}

interface MasterdataChoice {
  id: string;
  code: string | null;
  value: string;
  allowedFor?: string[] | null;
  active?: boolean;
}

interface MasterdataResponse {
  fieldId: string;
  fieldName: string;
  fieldType: string;
  properties: {
    Choices?: MasterdataChoice[];
    ChoicesDesigner?: MasterdataChoice[];
    ParentField?: string;
  };
}

async function getBeProductToken(): Promise<string> {
  // Use refresh token grant if available (preferred)
  if (BEPRODUCT_REFRESH_TOKEN) {
    const resp = await fetch("https://id.winks.io/ids/connect/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        client_id: BEPRODUCT_CLIENT_ID,
        client_secret: BEPRODUCT_CLIENT_SECRET,
        refresh_token: BEPRODUCT_REFRESH_TOKEN,
      }),
    });

    if (!resp.ok) {
      const error = await resp.text();
      throw new Error(`Failed to authenticate with BeProduct (refresh): ${resp.status} ${error}`);
    }

    const data: BeProductTokenResponse = await resp.json();
    console.log("Authenticated via refresh token grant");
    return data.access_token;
  }

  // Fallback to client credentials
  const resp = await fetch("https://id.winks.io/ids/connect/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: BEPRODUCT_CLIENT_ID,
      client_secret: BEPRODUCT_CLIENT_SECRET,
    }),
  });

  if (!resp.ok) {
    const error = await resp.text();
    throw new Error(`Failed to authenticate with BeProduct (client_credentials): ${resp.status} ${error}`);
  }

  const data: BeProductTokenResponse = await resp.json();
  console.log("Authenticated via client credentials grant");
  return data.access_token;
}

async function fetchMasterdata(fieldId: string, token: string): Promise<MasterdataResponse> {
  const url = `${BEPRODUCT_BASE_URL}/api/${BEPRODUCT_COMPANY}/MasterData/${fieldId}`;
  console.log(`Fetching: ${url}`);
  
  const resp = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  if (!resp.ok) {
    const error = await resp.text();
    console.error(`Failed to fetch ${fieldId}: ${resp.status} - ${error}`);
    throw new Error(`Failed to fetch masterdata for ${fieldId}: ${resp.status} ${error}`);
  }

  return await resp.json();
}

// Table creation no longer needed - using unified config.app_config table

Deno.serve(async (req: Request) => {
  try {
    console.log("Starting BeProduct masterdata sync...");

    // Authenticate with BeProduct
    const token = await getBeProductToken();
    console.log("Authenticated with BeProduct");

    // Create Supabase client
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { synced: number; errors: string[] }> = {};

    // Sync each field
    for (const fieldId of FIELDS) {
      try {
        console.log(`Fetching masterdata for ${fieldId}...`);
        const data = await fetchMasterdata(fieldId, token);
        
        const choices = data.properties?.ChoicesDesigner || data.properties?.Choices || [];
        let syncedCount = 0;
        const errors: string[] = [];

        // Debug: print allowedFor for product_type
        if (fieldId === "product_type") {
          console.log("Sample allowedFor values for product_type:",
            choices.slice(0, 10).map(c => ({ value: c.value, allowedFor: c.allowedFor }))
          );
        }

        // Build batch upsert SQL for config.app_config
        const values = choices
          .filter(c => c.value || c.code)
          .map(choice => {
            const category = fieldId.replace(/'/g, "''");
            const key = (choice.code || choice.id).replace(/'/g, "''");
            const value = (choice.value || "").replace(/'/g, "''");
            const active = choice.active ?? true;
            const allowedFor = choice.allowedFor 
              ? `'${JSON.stringify(choice.allowedFor).replace(/'/g, "''")}'::jsonb`
              : 'NULL';
            return `('${category}', '${key}', '${value}', ${active}, ${allowedFor}, now(), 'enum', 'text')`;
          })
          .join(',\n        ');
        
        if (values) {
          const { error: upsertError } = await supabase.rpc("exec_sql", {
            sql: `
              INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type)
              VALUES ${values}
              ON CONFLICT (category, key) DO UPDATE SET
                value = EXCLUDED.value,
                is_active = EXCLUDED.is_active,
                allowed_for = EXCLUDED.allowed_for,
                last_synced_at = EXCLUDED.last_synced_at,
                updated_at = now();
            `
          });
          
          if (upsertError) {
            errors.push(`Batch upsert failed: ${upsertError.message}`);
          } else {
            syncedCount = choices.filter(c => c.value || c.code).length;
          }
        }

        results[fieldId] = { synced: syncedCount, errors };
        console.log(`Synced ${syncedCount} values for ${fieldId} to config.app_config`);
      } catch (err) {
        results[fieldId] = {
          synced: 0,
          errors: [err instanceof Error ? err.message : String(err)],
        };
        console.error(`Error syncing ${fieldId}:`, err);
      }
    }

    return new Response(
      JSON.stringify({
        status: "completed",
        timestamp: new Date().toISOString(),
        results,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          Connection: "keep-alive",
        },
      }
    );
  } catch (error) {
    console.error("Fatal error:", error);
    return new Response(
      JSON.stringify({
        status: "error",
        message: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          Connection: "keep-alive",
        },
      }
    );
  }
});
