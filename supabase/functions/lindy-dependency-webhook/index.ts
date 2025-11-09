import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Lindy response payload
interface LindyDependencyPayload {
  tracking_url: string;
  folder_id: string;
  plan_id: string;
  dependencies: DependencyRow[];
}

interface DependencyRow {
  row_number: number;
  department: string | null;
  action_description: string;
  short_description: string | null;
  share_with: string | null;
  page: string | null;
  days: number;
  depends_on: string | null;
  duration: number;
  duration_unit: string | null;
  relationship: string | null;
}

async function upsertPlanDependencies(
  client: any,
  planId: string,
  dependencies: DependencyRow[]
): Promise<void> {
  // Add START DATE bookend (row 0)
  const startDateRow: DependencyRow = {
    row_number: 0,
    department: 'PLAN',
    action_description: 'START DATE',
    short_description: 'START DATE',
    share_with: null,
    page: null,
    days: 0,
    depends_on: null,
    duration: 0,
    duration_unit: null,
    relationship: null,
  };
  
  // Add END DATE bookend (row 99)
  const endDateRow: DependencyRow = {
    row_number: 99,
    department: 'PLAN',
    action_description: 'END DATE',
    short_description: 'END DATE',
    share_with: null,
    page: null,
    days: 0,
    depends_on: null,
    duration: 0,
    duration_unit: null,
    relationship: null,
  };
  
  const allDependencies = [startDateRow, ...dependencies, endDateRow];
  
  // Delete existing dependencies for this plan
  await client
    .from('tracking_plan_dependencies')
    .delete()
    .eq('plan_id', planId);
  
  // Insert all dependencies
  const records = allDependencies.map(dep => ({
    plan_id: planId,
    row_number: dep.row_number,
    department: dep.department,
    action_description: dep.action_description,
    short_description: dep.short_description,
    share_with: dep.share_with,
    page: dep.page,
    days: dep.days,
    depends_on: dep.depends_on,
    duration: dep.duration,
    duration_unit: dep.duration_unit,
    relationship: dep.relationship,
  }));
  
  const { error } = await client
    .from('tracking_plan_dependencies')
    .insert(records);
  
  if (error) {
    throw new Error(`Failed to insert dependencies: ${error.message}`);
  }
  
  console.log(`✅ Inserted ${records.length} dependencies for plan ${planId}`);
}

async function updateTimelineDependencies(
  client: any,
  planId: string,
  dependencies: DependencyRow[]
): Promise<void> {
  console.log(`📊 Updating timeline records with dependency info for plan ${planId}...`);
  
  // Add bookends to dependency list
  const startDateRow: DependencyRow = {
    row_number: 0,
    department: 'PLAN',
    action_description: 'START DATE',
    short_description: 'START DATE',
    share_with: null,
    page: null,
    days: 0,
    depends_on: null,
    duration: 0,
    duration_unit: null,
    relationship: null,
  };
  
  const endDateRow: DependencyRow = {
    row_number: 99,
    department: 'PLAN',
    action_description: 'END DATE',
    short_description: 'END DATE',
    share_with: null,
    page: null,
    days: 0,
    depends_on: null,
    duration: 0,
    duration_unit: null,
    relationship: null,
  };
  
  const allDependencies = [startDateRow, ...dependencies, endDateRow];
  
  // Get all styles for this plan
  const { data: styles, error: stylesError } = await client
    .from('tracking_plan_style')
    .select('id')
    .eq('plan_id', planId);
  
  if (stylesError) {
    console.error(`Failed to fetch styles for plan ${planId}:`, stylesError);
    return;
  }
  
  if (!styles || styles.length === 0) {
    console.warn(`No styles found for plan ${planId}`);
    return;
  }
  
  console.log(`Found ${styles.length} styles to update`);
  
  // For each style, update timeline records with dependency info
  let updatedCount = 0;
  for (const style of styles) {
    // Build a map of milestone names to timeline IDs for this style (for UUID lookups)
    const { data: allTimelines, error: timelineError } = await client
      .from('tracking_plan_style_timeline')
      .select('id, milestone_name')
      .eq('plan_style_id', style.id);
    
    if (timelineError) {
      console.error(`Failed to fetch timelines for style ${style.id}:`, timelineError);
      continue;
    }
    
    const milestoneNameToId: Record<string, string> = {};
    if (allTimelines) {
      for (const timeline of allTimelines) {
        if (timeline.milestone_name) {
          milestoneNameToId[timeline.milestone_name] = timeline.id;
        }
      }
    }
    
    for (const dep of allDependencies) {
      // Match timeline by milestone name (case-insensitive)
      const { data: matchingTimelines, error: matchError } = await client
        .from('tracking_plan_style_timeline')
        .select('id, milestone_name')
        .eq('plan_style_id', style.id)
        .ilike('milestone_name', dep.action_description);
      
      if (matchError) {
        console.error(`Error matching timeline for ${dep.action_description}:`, matchError);
        continue;
      }
      
      // Update matching timeline records
      if (matchingTimelines && matchingTimelines.length > 0) {
        for (const timeline of matchingTimelines) {
          // Find predecessor UUID if depends_on is set
          let dependencyUuid: string | null = null;
          if (dep.depends_on && milestoneNameToId[dep.depends_on]) {
            dependencyUuid = milestoneNameToId[dep.depends_on];
          }
          
          const { error: updateError } = await client
            .from('tracking_plan_style_timeline')
            .update({
              row_number: dep.row_number,
              depends_on: dep.depends_on,
              dependency_uuid: dependencyUuid,
              relationship: dep.relationship,
              updated_at: new Date().toISOString(),
            })
            .eq('id', timeline.id);
          
          if (updateError) {
            console.error(`Failed to update timeline ${timeline.id}:`, updateError);
          } else {
            updatedCount++;
            if (dependencyUuid) {
              console.log(`  Updated ${dep.action_description} -> depends on ${dep.depends_on} (UUID: ${dependencyUuid})`);
            }
          }
        }
      }
    }
  }
  
  console.log(`✅ Updated ${updatedCount} timeline records with dependency info`);
}

// Main handler
Deno.serve(async (req: Request) => {
  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  // Handle OPTIONS request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("📥 Received Lindy dependency webhook");
    
    // Parse payload
    const payload: LindyDependencyPayload = await req.json();
    
    console.log(`Plan ID: ${payload.plan_id}`);
    console.log(`Folder ID: ${payload.folder_id}`);
    console.log(`Tracking URL: ${payload.tracking_url}`);
    console.log(`Dependencies received: ${payload.dependencies.length}`);

    // Validate required fields
    if (!payload.plan_id) {
      return new Response(
        JSON.stringify({ error: "Missing plan_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!payload.dependencies || !Array.isArray(payload.dependencies)) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid dependencies array" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        db: { schema: "ops" },
      }
    );

    // Verify plan exists
    const { data: plan, error: planError } = await supabaseClient
      .from("tracking_plan")
      .select("id, name")
      .eq("id", payload.plan_id)
      .single();

    if (planError || !plan) {
      console.warn(`Plan ${payload.plan_id} not found in database`);
      return new Response(
        JSON.stringify({ 
          error: "Plan not found",
          plan_id: payload.plan_id 
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`✅ Found plan: ${plan.name}`);

    // Store dependencies with START/END bookends
    await upsertPlanDependencies(supabaseClient, payload.plan_id, payload.dependencies);

    // Now call the SQL function to populate timeline dependencies from tracking_plan_dependencies
    const { data: populateResult, error: populateError } = await supabaseClient.rpc(
      'populate_timeline_dependencies',
      { p_plan_id: payload.plan_id }
    );

    if (populateError) {
      console.error(`Failed to populate timeline dependencies:`, populateError);
      throw new Error(`Failed to populate timeline dependencies: ${populateError.message}`);
    }

    const updatedCount = populateResult?.[0]?.updated_count ?? 0;
    console.log(`✅ Populated ${updatedCount} timeline records with dependency UUIDs and relationships`);

    // Log success
    await supabaseClient.from("beproduct_sync_log").insert({
      entity_type: "tracking_dependency",
      entity_id: payload.plan_id,
      action: "Lindy_DependencyReceived",
      payload: payload,
    });

    console.log(`✅ Successfully processed ${payload.dependencies.length + 2} dependencies (including START/END)`);

    return new Response(
      JSON.stringify({ 
        ok: true, 
        plan_id: payload.plan_id,
        dependencies_stored: payload.dependencies.length + 2 
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Lindy webhook error:", error);

    return new Response(
      JSON.stringify({
        error: error.message,
        stack: error.stack,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
