import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Types
interface WebhookPayload {
  eventType: "OnCreate" | "OnChange" | "OnDelete";
  objectType: string;
  headerId: string;
  headerNumber: string;
  headerName: string;
  folderId: string;
  folderName: string;
  data: {
    before?: TimelineRecord;
    after?: TimelineRecord;
    planId: string;
    planFolderId: string;
    timelineId?: string;
    timeLineSchema?: TimelineSchema;
  };
  user: {
    id: string;
    userName: string;
  };
  date: string;
}

interface TimelineRecord {
  Id: string;
  PlanId: string;
  CompanyId: string;
  MasterFolder: string;
  HeaderId: string;
  Color: {
    _id: string;
    color_source_id?: string | null;
    suggested_name: string;
    suggested_hex?: string;
  };
  Size?: string;
  StyleId?: string | null;
  StyleColor?: {
    _id: string;
    suggested_name: string;
    suggested_hex: string;
  };
  Supplier?: any[];
  ModifiedAt: string;
  ModifiedBy: {
    user_id: string;
    user_name: string;
  };
  Timelines?: TimelineMilestone[];
  TimeLineItem?: TimelineMilestone;
  Aggregates?: any;
  Order?: number;
  MarkedForDelete?: boolean;
}

interface TimelineMilestone {
  Id: string;
  TimeLineId: string;
  Status: string;
  Rev: string | null;
  Final: string | null;
  DueDate: string;
  ProjectDate: string;
  AssignedTo: AssignedUser[];
  ShareWith: AssignedUser[];
  Late: boolean;
  SubmitsQuantity?: number;
}

interface AssignedUser {
  value: string;
  code: string;
}

interface TimelineSchema {
  Plan: string;
  DueDate: string | null;
  PlanDateOverride: string | null;
  Id: string;
  Department: string;
  TaskDescription: string;
  ShortDescription: string;
  AssignedTo: any[];
  Page: string | null;
  Days: number;
  GroupTask: string;
  LinkFolder: string;
  Calendar: string;
  CalendarDays: number;
  When: string;
  ActDesc: string;
  RevisedDays: number;
  ShareWhen: string;
  SharedPermission: string;
  DefaultStatus: string;
  ExternalShareWith: any[];
  AutoShareLinkedPage: boolean;
  SyncWithGroupTask: boolean;
}

const ALLOWED_STATUS_MAP: Record<string, string> = {
  "not started": "Not Started",
  "not_started": "Not Started",
  "not-started": "Not Started",
  "in progress": "In Progress",
  "in_progress": "In Progress",
  "in-progress": "In Progress",
  "approved": "Approved",
  "approved with corrections": "Approved with corrections",
  "approved_with_corrections": "Approved with corrections",
  "approved-with-corrections": "Approved with corrections",
  "rejected": "Rejected",
  "complete": "Complete",
  "completed": "Complete",
  "waiting on": "Waiting On",
  "waiting_on": "Waiting On",
  "waiting-on": "Waiting On",
  "na": "NA",
  "n/a": "NA",
};

function normalizeStatus(value: string | null | undefined): string {
  if (!value) return "Not Started";
  const key = value.trim().toLowerCase();
  return ALLOWED_STATUS_MAP[key] ?? "Not Started";
}

// Helper functions
async function getAccessToken(): Promise<string> {
  const clientId = Deno.env.get("BEPRODUCT_CLIENT_ID");
  const clientSecret = Deno.env.get("BEPRODUCT_CLIENT_SECRET");
  const refreshToken = Deno.env.get("BEPRODUCT_REFRESH_TOKEN");

  if (!clientId || !clientSecret) {
    throw new Error("BeProduct credentials not configured (CLIENT_ID, CLIENT_SECRET)");
  }

  // Use refresh token grant if available (preferred)
  if (refreshToken) {
    const response = await fetch("https://id.winks.io/ids/connect/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Failed to get access token (refresh): ${response.status} ${errorText}`);
    }

    const data = await response.json();
    return data.access_token;
  }

  // Fallback to client credentials
  const response = await fetch("https://id.winks.io/ids/connect/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to get access token (client_credentials): ${response.status} ${errorText}`);
  }

  const data = await response.json();
  return data.access_token;
}

async function checkPlanExists(
  client: any,
  planId: string
): Promise<boolean> {
  const { data, error } = await client
    .from("tracking_plan")
    .select("id")
    .eq("id", planId)
    .single();

  return !error && !!data;
}

async function fetchPlanFromBeProduct(planId: string, accessToken: string): Promise<any> {
  const baseUrl = Deno.env.get("BEPRODUCT_BASE_URL") || "https://developers.beproduct.com";
  const company = Deno.env.get("BEPRODUCT_COMPANY") || "activeapparelgroup";

  const response = await fetch(
    `${baseUrl}/api/${company}/Tracking/Plan/${planId}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: "",
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to fetch plan: ${response.status} ${response.statusText}${errorText ? ` - ${errorText}` : ""}`,
    );
  }

  return await response.json();
}

async function fetchFolderListFromBeProduct(accessToken: string): Promise<any> {
  const baseUrl = Deno.env.get("BEPRODUCT_BASE_URL") || "https://developers.beproduct.com";
  const company = Deno.env.get("BEPRODUCT_COMPANY") || "activeapparelgroup";

  const response = await fetch(
    `${baseUrl}/api/${company}/Tracking/Folders`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch folders: ${response.statusText}`);
  }

  return await response.json();
}

async function upsertPlan(client: any, planData: any): Promise<void> {
  const { error } = await client
    .from("tracking_plan")
    .upsert({
      id: planData.id,
      name: planData.name,
      description: planData.description,
      folder_id: planData.folderId,
      start_date: planData.startDate ? planData.startDate.split("T")[0] : null,
      end_date: planData.endDate ? planData.endDate.split("T")[0] : null,
      template_id: planData.templateId,
      active: planData.active !== false,
      raw_payload: planData,
      created_at: planData.createdAt,
      updated_at: planData.modifiedAt,
      created_by: planData.createdBy?.name,
      updated_by: planData.modifiedBy?.name,
    }, {
      onConflict: "id",
    });

  if (error) {
    throw new Error(`Failed to upsert plan: ${error.message}`);
  }
}

async function upsertFolder(
  client: any,
  folderData: {
    id: string;
    name: string;
    brand?: string | null;
    style_folder_id?: string | null;
    style_folder_name?: string | null;
    active?: boolean | null;
    raw_payload?: any;
  }
): Promise<void> {
  const { error } = await client
    .from("tracking_folder")
    .upsert({
      id: folderData.id,
      name: folderData.name,
      brand: folderData.brand ?? extractBrand(folderData.name),
      style_folder_id: folderData.style_folder_id ?? null,
      style_folder_name: folderData.style_folder_name ?? null,
      active: folderData.active ?? true,
      raw_payload: folderData.raw_payload ?? null,
    }, {
      onConflict: "id",
    });

  if (error) {
    throw new Error(`Failed to upsert folder: ${error.message}`);
  }
}

function extractBrand(folderName: string): string | null {
  // Extract brand from folder name (e.g., "GREYSON MENS" -> "GREYSON")
  const parts = folderName.split(" ");
  return parts.length > 0 ? parts[0] : null;
}

async function getFolderRecord(
  client: any,
  folderId: string
): Promise<{ id: string; name: string; style_folder_name?: string | null } | null> {
  const { data, error } = await client
    .from("tracking_folder")
    .select("id, name, style_folder_name")
    .eq("id", folderId)
    .limit(1);

  if (error) {
    console.warn(`Failed to fetch folder record ${folderId}:`, error.message);
    return null;
  }

  return (data && data.length > 0) ? data[0] : null;
}

async function fetchFolderDetails(
  folderId: string,
  accessToken: string
): Promise<any | null> {
  try {
    const list = await fetchFolderListFromBeProduct(accessToken);
    if (!Array.isArray(list)) {
      console.warn("Unexpected folder list response", list);
      return null;
    }

    return list.find((item) => {
      const id = item?.id ?? item?.Id;
      return id === folderId;
    }) ?? null;
  } catch (error) {
    console.error(`Failed to resolve folder ${folderId} from BeProduct:`, error);
    return null;
  }
}

function transformFolderPayload(
  folderId: string,
  fallbackName: string,
  folderInfo: any | null
) {
  if (!folderInfo) {
    return {
      id: folderId,
      name: fallbackName,
      brand: extractBrand(fallbackName),
      style_folder_id: null,
      style_folder_name: null,
      active: true,
      raw_payload: null,
    };
  }

  const name = folderInfo.name ?? folderInfo.Name ?? fallbackName;
  const styleFolder = folderInfo.styleFolder ?? folderInfo.StyleFolder ?? null;

  const styleFolderId = styleFolder?.id ?? styleFolder?.Id ?? folderInfo.styleFolderId ?? folderInfo.StyleFolderId ?? null;
  const styleFolderName = styleFolder?.name ?? styleFolder?.Name ?? folderInfo.styleFolderName ?? folderInfo.StyleFolderName ?? null;
  const brand = folderInfo.brand ?? folderInfo.Brand ?? extractBrand(name);
  const activeValue = folderInfo.active ?? folderInfo.Active ?? folderInfo.isActive ?? folderInfo.IsActive;

  return {
    id: folderId,
    name,
    brand: brand ?? extractBrand(name),
    style_folder_id: styleFolderId ?? null,
    style_folder_name: styleFolderName ?? null,
    active: activeValue === undefined ? true : Boolean(activeValue),
    raw_payload: folderInfo,
  };
}

async function upsertPlanStyle(client: any, styleData: any): Promise<void> {
  const { error } = await client
    .from("tracking_plan_style")
    .upsert({
      id: styleData.id,
      plan_id: styleData.plan_id,
      style_header_id: styleData.style_header_id,
      color_id: styleData.color_id,
      style_number: styleData.style_number,
      style_name: styleData.style_name,
      color_name: styleData.color_name,
      supplier_name: styleData.supplier_name,
      active: styleData.active !== false,
      raw_payload: styleData.raw_payload ?? null,
    }, {
      onConflict: "id",
    });

  if (error) {
    throw new Error(`Failed to upsert plan style: ${error.message}`);
  }
}

async function upsertTimeline(client: any, timelineData: any): Promise<void> {
  const normalizedStatus = normalizeStatus(timelineData.status);
  const normalizedDefaultStatus = timelineData.default_status
    ? normalizeStatus(timelineData.default_status)
    : null;

  const { error } = await client
    .from("tracking_plan_style_timeline")
    .upsert({
      id: timelineData.id,
      plan_style_id: timelineData.plan_style_id,
      template_item_id: timelineData.template_item_id,
      status: normalizedStatus,
      plan_date: timelineData.plan_date ? timelineData.plan_date.split("T")[0] : null,
      rev_date: timelineData.rev_date ? timelineData.rev_date.split("T")[0] : null,
      final_date: timelineData.final_date ? timelineData.final_date.split("T")[0] : null,
      due_date: timelineData.due_date ? timelineData.due_date.split("T")[0] : null,
      late: timelineData.late || false,
      milestone_name: timelineData.milestone_name,
      milestone_short_name: timelineData.milestone_short_name,
      dept_customer: timelineData.department,
      milestone_page_name: timelineData.milestone_page_name,
      offset_days: timelineData.offset_days,
      calendar_days: timelineData.calendar_days,
      calendar_name: timelineData.calendar_name,
      group_task: timelineData.group_task,
      when_rule: timelineData.when_rule,
      share_when_rule: timelineData.share_when_rule,
      activity_description: timelineData.activity_description,
      revised_days: timelineData.revised_days,
      default_status: normalizedDefaultStatus,
      auto_share_linked_page: timelineData.auto_share_linked_page,
      sync_with_group_task: timelineData.sync_with_group_task,
      external_share_with: timelineData.external_share_with,
      row_number: timelineData.row_number ?? null,
      depends_on: timelineData.depends_on ?? null,
      dependency_uuid: timelineData.dependency_uuid ?? null,
      raw_payload: timelineData.raw_payload ?? null,
    }, {
      onConflict: "id",
    });

  if (error) {
    throw new Error(`Failed to upsert timeline: ${error.message}`);
  }
}

async function triggerLindyDependencyFetch(planId: string, folderId: string): Promise<void> {
  const lindyWebhookUrl = Deno.env.get("LINDY_WEBHOOK_URL") || 
    "https://public.lindy.ai/api/v1/webhooks/lindy/07cbcafe-866e-4b84-8a0a-aa2c28ff2eea";
  
  const beproductBaseUrl = Deno.env.get("BEPRODUCT_BASE_URL") || "https://hk.beproduct.com";
  const company = Deno.env.get("BEPRODUCT_COMPANY") || "activeapparelgroup";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "https://bcvacwoofvygdmxbqsaq.supabase.co";
  
  // Construct BeProduct tracking plan URL
  const trackingUrl = `${beproductBaseUrl}/${company}/Tracking#/Tracking/${folderId}/Style/plan/${planId}/setup?useFavorite=true`;
  
  // Construct callback URL for Lindy to send results
  const callbackUrl = `${supabaseUrl}/functions/v1/lindy-dependency-webhook`;
  
  console.log(`🚀 Triggering Lindy dependency fetch for plan ${planId}`);
  console.log(`   Tracking URL: ${trackingUrl}`);
  console.log(`   Callback URL: ${callbackUrl}`);
  
  try {
    // Fire and forget - don't await response
    fetch(lindyWebhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ 
        url: trackingUrl,
        callback_url: callbackUrl
      }),
    }).catch(error => {
      console.error(`Failed to trigger Lindy webhook:`, error);
    });
    
    console.log(`✅ Lindy webhook triggered (processing asynchronously)`);
  } catch (error) {
    console.error(`Error triggering Lindy webhook:`, error);
    // Don't throw - we don't want to fail the main webhook if Lindy trigger fails
  }
}

// DependencyRow interface removed - now handled by lindy-dependency-webhook function
// CSV parsing removed - Lindy sends JSON directly to callback webhook
// upsertPlanDependencies removed - now handled by lindy-dependency-webhook function

async function logSync(client: any, payload: WebhookPayload): Promise<void> {
  await client.from("beproduct_sync_log").insert({
    entity_type: "tracking",
    entity_id: payload.headerId,
    action: payload.eventType,
    payload: payload,
  });
}

// Event handlers
async function handleOnCreate(
  client: any,
  payload: WebhookPayload
): Promise<void> {
  console.log("Handling OnCreate event...");

  const planId = payload.data.planId;
  const folderId = payload.data.planFolderId;

  // Get access token for BeProduct API calls if needed
  let accessToken: string | null = null;

  // 1. Ensure folder exists before plan upsert to satisfy foreign key constraints
  const existingFolder = await getFolderRecord(client, folderId);
  const needsFolderUpdate = !existingFolder
    || existingFolder.name === payload.folderName
    || !existingFolder.style_folder_name;

  if (needsFolderUpdate) {
    console.log(`Folder ${folderId} missing or incomplete, fetching from BeProduct...`);
    if (!accessToken) {
      accessToken = await getAccessToken();
    }
    const folderInfo = await fetchFolderDetails(folderId, accessToken);
    const folderPayload = transformFolderPayload(folderId, payload.folderName, folderInfo);
    await upsertFolder(client, folderPayload);
  }

  // 2. Always fetch plan/timeline schema from BeProduct on OnCreate
  let planData = null;
  let fetchError = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      if (!accessToken) {
        accessToken = await getAccessToken();
      }
      planData = await fetchPlanFromBeProduct(planId, accessToken);
      break;
    } catch (err) {
      fetchError = err;
      console.warn(`Attempt ${attempt + 1} to fetch plan failed:`, err.message);
      if (attempt === 0) {
        await new Promise(res => setTimeout(res, 1000));
      }
    }
  }
  if (!planData) {
    throw new Error(`Failed to fetch plan from BeProduct after retries: ${fetchError?.message}`);
  }
  await upsertPlan(client, { ...planData, raw_payload: planData });
  await triggerLindyDependencyFetch(planId, folderId);

  // Ensure 'after' is initialized before any reference
  if (!payload.data.after) {
    throw new Error("Missing 'after' data in OnCreate event");
  }
  const after = payload.data.after;
  const supplierName = after.Supplier && after.Supplier.length > 0
    ? after.Supplier[0].name || after.Supplier[0]
    : null;
  await upsertPlanStyle(client, {
    id: after.Id,
    plan_id: planId,
    style_header_id: payload.headerId,
    color_id: after.Color._id,
    style_number: payload.headerNumber,
    style_name: payload.headerName,
    color_name: after.Color.suggested_name,
    supplier_name: supplierName,
    active: true,
    raw_payload: after,
  });

  // 4. Upsert timeline milestones
  // Build a lookup for TimelineSchemas from planData
  let timelineSchemas: any[] = [];
  if (planData?.style?.timelines) timelineSchemas = planData.style.timelines;
  if (planData?.timelines) timelineSchemas = planData.timelines;
  // fallback for material timelines if needed

  // 4a. Synthesize START DATE milestone (row 0)
  const startDateId = crypto.randomUUID();
  const startDate = planData.startDate || planData.StartDate;
  await upsertTimeline(client, {
    id: startDateId,
    plan_style_id: after.Id,
    template_item_id: null,
    status: "Complete",
    plan_date: startDate ? (typeof startDate === 'string' ? startDate.split('T')[0] : startDate) : null,
    due_date: startDate ? (typeof startDate === 'string' ? startDate.split('T')[0] : startDate) : null,
    late: false,
    milestone_name: "START DATE",
    milestone_short_name: "START DATE",
    department: "PLAN",
    row_number: 0,
    depends_on: null,
    relationship: null,
    raw_payload: { synthesized: true, source: "tracking_plan.start_date" },
  });

  // 4b. Upsert existing timeline milestones from BeProduct
  if (after.Timelines) {
    for (const timeline of after.Timelines) {
      // Find matching TimelineSchema for this milestone
      let schema: any = timelineSchemas.find((s: any) => s.id === timeline.TimeLineId);
      // fallback for alternate key
      if (!schema) schema = timelineSchemas.find((s: any) => s.Id === timeline.TimeLineId);
      await upsertTimeline(client, {
        id: timeline.Id,
        plan_style_id: after.Id,
        template_item_id: timeline.TimeLineId,
        status: timeline.Status || "Not Started",
        plan_date: timeline.ProjectDate,
        rev_date: timeline.Rev,
        final_date: timeline.Final,
        due_date: timeline.DueDate,
        late: timeline.Late,
        // Milestone metadata from TimelineSchema
        milestone_name: schema?.actionDescription ?? schema?.TaskDescription ?? null,
        milestone_short_name: schema?.shortDescription ?? schema?.ShortDescription ?? null,
        department: schema?.department ?? schema?.Department ?? null,
        milestone_page_name: schema?.pageName ?? schema?.Page ?? null,
        offset_days: schema?.Days ?? null,
        calendar_days: schema?.CalendarDays ?? null,
        calendar_name: schema?.Calendar ?? null,
        group_task: schema?.GroupTask ?? null,
        when_rule: schema?.When ?? null,
        share_when_rule: schema?.ShareWhen ?? null,
        activity_description: schema?.ActDesc ?? null,
        revised_days: schema?.RevisedDays ?? null,
        default_status: schema?.DefaultStatus ?? null,
        auto_share_linked_page: schema?.AutoShareLinkedPage ?? null,
        sync_with_group_task: schema?.SyncWithGroupTask ?? null,
        external_share_with: schema?.ExternalShareWith ?? null,
        row_number: null, // Will be populated by Lindy webhook
        depends_on: null, // Will be populated by Lindy webhook
        relationship: null, // Will be populated by Lindy webhook
        raw_payload: timeline,
      });
      // Sync assignments for onCreate (no before state)
      if (timeline.AssignedTo && timeline.AssignedTo.length > 0) {
        const assignments = timeline.AssignedTo.map((user: any) => ({
          timeline_id: timeline.Id,
          assignee_id: user.code,
          source_user_id: user.code,
        }));
        await client
          .from("tracking_timeline_assignment")
          .insert(assignments);
      }
    }
  }

  // 4c. Synthesize END DATE milestone (row 99)
  const endDateId = crypto.randomUUID();
  const endDate = planData.endDate || planData.EndDate;
  await upsertTimeline(client, {
    id: endDateId,
    plan_style_id: after.Id,
    template_item_id: null,
    status: "Not Started",
    plan_date: endDate ? (typeof endDate === 'string' ? endDate.split('T')[0] : endDate) : null,
    due_date: endDate ? (typeof endDate === 'string' ? endDate.split('T')[0] : endDate) : null,
    late: false,
    milestone_name: "END DATE",
    milestone_short_name: "END DATE",
    department: "PLAN",
    row_number: 99,
    depends_on: null,
    relationship: null,
    raw_payload: { synthesized: true, source: "tracking_plan.end_date" },
  });

  // 6. Recalculate start dates for the plan
  await recalculateStartDates(client, planId);

  console.log("OnCreate event handled successfully");
}

async function recalculateStartDates(client: any, planId: string): Promise<void> {
  console.log(`Recalculating start dates for plan ${planId}...`);
  
  try {
    const { data, error } = await client.rpc('calculate_timeline_start_dates', {
      p_plan_id: planId
    });

    if (error) {
      console.error(`Failed to recalculate start dates: ${error.message}`);
      throw error;
    }

    console.log(`Recalculated start dates for ${data?.length || 0} timeline records`);
  } catch (err) {
    console.error("Error in recalculateStartDates:", err);
    throw err;
  }
}

async function handleOnChange(
  client: any,
  payload: WebhookPayload
): Promise<void> {
  console.log("Handling OnChange event...");


  const before = payload.data.before?.TimeLineItem;
  const after = payload.data.after?.TimeLineItem;

  if (!before || !after) {
    console.warn("Missing before/after TimeLineItem data in OnChange event");
    return;
  }

  const timelineId = after.Id;

  // Explicit logging of before/after values for key fields
  console.log("Timeline update details:");
  console.log({
    timelineId: timelineId,
    styleId: after.StyleId ?? null,
    colorway: after.StyleColor?.suggested_name ?? after.Color?.suggested_name ?? null,
    milestone: after.Status ?? null,
    before_status: before.Status,
    after_status: after.Status,
    before_rev_date: before.Rev,
    after_rev_date: after.Rev,
    before_final_date: before.Final,
    after_final_date: after.Final,
    before_due_date: before.DueDate,
    after_due_date: after.DueDate,
    before_plan_date: before.ProjectDate,
    after_plan_date: after.ProjectDate,
    before_submits_quantity: before.SubmitsQuantity,
    after_submits_quantity: after.SubmitsQuantity,
    before_assignments: before.AssignedTo?.map(a => a.code),
    after_assignments: after.AssignedTo?.map(a => a.code),
  });

  // 1. Build complete timeline object from after state
  const timelineData: any = {
    id: timelineId,
    status: normalizeStatus(after.Status || before.Status || "Not Started"),
    plan_date: after.ProjectDate ? after.ProjectDate.split("T")[0] : null,
    rev_date: after.Rev ? after.Rev.split("T")[0] : null,
    final_date: after.Final ? after.Final.split("T")[0] : null,
    due_date: after.DueDate ? after.DueDate.split("T")[0] : null,
    late: after.Late,
    shared_with: after.ShareWith,
    submits_quantity: after.SubmitsQuantity ?? 0,
    raw_payload: after,
    updated_at: new Date().toISOString(),
  };

  // 2. Upsert the timeline record
  const { error } = await client
    .from("tracking_plan_style_timeline")
    .update(timelineData)
    .eq("id", timelineId);

  if (error) {
    throw new Error(`Failed to update timeline: ${error.message}`);
  }

  // 3. Sync assignments using before/after comparison (same pattern as materials/styles)
  const beforeAssignments = before.AssignedTo || [];
  const afterAssignments = after.AssignedTo || [];
  
  const beforeAssignmentIds = beforeAssignments.map((a: any) => a.code).filter((id: any) => id);
  const afterAssignmentIds = afterAssignments.map((a: any) => a.code).filter((id: any) => id);
  const deletedAssignmentIds = beforeAssignmentIds.filter((id: any) => !afterAssignmentIds.includes(id));

  // Delete removed assignments
  if (deletedAssignmentIds.length > 0) {
    await client
      .from("tracking_timeline_assignment")
      .delete()
      .eq("timeline_id", timelineId)
      .in("assignee_id", deletedAssignmentIds);
    console.log(`Deleted ${deletedAssignmentIds.length} removed assignments`);
  }

  // Upsert current assignments
  if (afterAssignments && afterAssignments.length > 0) {
    const assignments = afterAssignments.map((user: any) => ({
      timeline_id: timelineId,
      assignee_id: user.code,
      source_user_id: user.code,
    }));

    const { error: assignError } = await client
      .from("tracking_timeline_assignment")
      .upsert(assignments, { onConflict: "timeline_id,assignee_id" });

    if (assignError) {
      console.error(`Failed to upsert assignments: ${assignError.message}`);
    } else {
      console.log(`Upserted ${assignments.length} assignments`);
    }
  } else if (afterAssignments && afterAssignments.length === 0 && beforeAssignmentIds.length > 0) {
    // Empty array = delete all
    await client
      .from("tracking_timeline_assignment")
      .delete()
      .eq("timeline_id", timelineId);
    console.log("Deleted all assignments (empty array)");
  }

  // 4. Get plan_id to recalculate start dates
  const { data: planData } = await client
    .from("tracking_plan_style_timeline")
    .select("plan_style_id, tracking_plan_style!inner(plan_id)")
    .eq("id", timelineId)
    .single();

  if (planData?.tracking_plan_style?.plan_id) {
    await recalculateStartDates(client, planData.tracking_plan_style.plan_id);
  }

  console.log("OnChange event handled successfully");
}

async function handleOnDelete(
  client: any,
  payload: WebhookPayload
): Promise<void> {
  console.log("Handling OnDelete event...");

  const before = payload.data.before;
  if (!before) {
    console.warn("Missing before data in OnDelete event");
    return;
  }

  const recordId = before.Id;

  // Soft delete
  const { error } = await client
    .from("tracking_plan_style")
    .update({ active: false })
    .eq("id", recordId);

  if (error) {
    throw new Error(`Failed to soft delete style: ${error.message}`);
  }

  console.log("OnDelete event handled successfully");
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
    // TEMPORARY: Authentication disabled for testing
    // const authHeader = req.headers.get("authorization");
    // const webhookSecret = Deno.env.get("BEPRODUCT_WEBHOOK_SECRET");
    //
    // if (webhookSecret && (!authHeader || !authHeader.includes(webhookSecret))) {
    //   return new Response(
    //     JSON.stringify({ error: "Unauthorized" }),
    //     {
    //       status: 401,
    //       headers: { ...corsHeaders, "Content-Type": "application/json" },
    //     }
    //   );
    // }

    // 2. Parse webhook payload
    const payload: WebhookPayload = await req.json();
    console.log(`Received ${payload.eventType} event for ${payload.headerNumber}`);

    // 3. Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        db: { schema: "ops" },
      }
    );

    // 4. Route to appropriate handler
    switch (payload.eventType) {
      case "OnCreate":
        await handleOnCreate(supabaseClient, payload);
        break;
      case "OnChange":
        await handleOnChange(supabaseClient, payload);
        break;
      case "OnDelete":
        await handleOnDelete(supabaseClient, payload);
        break;
      default:
        console.warn(`Unknown event type: ${payload.eventType}`);
    }

    // 5. Log sync
    await logSync(supabaseClient, payload);

    return new Response(
      JSON.stringify({ ok: true, eventType: payload.eventType }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Webhook error:", error);

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
