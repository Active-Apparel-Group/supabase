-- Migration: Add milestone name and metadata columns to timeline tables
-- These fields come from BeProduct webhook payload but were not being stored

-- ============================================================================
-- tracking_plan_style_timeline - Add milestone identification and metadata
-- ============================================================================

ALTER TABLE ops.tracking_plan_style_timeline
  ADD COLUMN IF NOT EXISTS milestone_name TEXT,
  ADD COLUMN IF NOT EXISTS milestone_short_name TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS milestone_page_name TEXT,
  
  -- Milestone configuration from TimelineSchema
  ADD COLUMN IF NOT EXISTS offset_days INTEGER,
  ADD COLUMN IF NOT EXISTS calendar_days INTEGER,
  ADD COLUMN IF NOT EXISTS calendar_name TEXT,
  ADD COLUMN IF NOT EXISTS group_task TEXT,
  ADD COLUMN IF NOT EXISTS when_rule TEXT,
  ADD COLUMN IF NOT EXISTS share_when_rule TEXT,
  ADD COLUMN IF NOT EXISTS activity_description TEXT,
  ADD COLUMN IF NOT EXISTS revised_days INTEGER,
  ADD COLUMN IF NOT EXISTS default_status TEXT,
  ADD COLUMN IF NOT EXISTS auto_share_linked_page BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS sync_with_group_task BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS external_share_with JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN ops.tracking_plan_style_timeline.milestone_name IS 'Full milestone name from BeProduct (TaskDescription/actionDescription)';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.milestone_short_name IS 'Short milestone name from BeProduct (ShortDescription/shortDescription)';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.department IS 'Department responsible for this milestone';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.milestone_page_name IS 'Associated page name (e.g., Proto Sample, Tech Pack)';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.offset_days IS 'Number of offset days from predecessor milestone';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.calendar_days IS 'Calendar days for duration calculation';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.calendar_name IS 'Calendar system to use for date calculations';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.group_task IS 'Task grouping identifier';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.when_rule IS 'Timing rule for milestone activation';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.share_when_rule IS 'Rule for when to share with external parties';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.activity_description IS 'Detailed activity description';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.revised_days IS 'Revised offset days if schedule changes';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.default_status IS 'Default status when milestone is created';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.auto_share_linked_page IS 'Automatically share linked page when milestone is shared';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.sync_with_group_task IS 'Sync dates with grouped task';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.external_share_with IS 'External parties to share with by default';

-- ============================================================================
-- tracking_plan_material_timeline - Add same columns for material timelines
-- ============================================================================

ALTER TABLE ops.tracking_plan_material_timeline
  ADD COLUMN IF NOT EXISTS milestone_name TEXT,
  ADD COLUMN IF NOT EXISTS milestone_short_name TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS milestone_page_name TEXT,
  
  -- Milestone configuration from TimelineSchema
  ADD COLUMN IF NOT EXISTS offset_days INTEGER,
  ADD COLUMN IF NOT EXISTS calendar_days INTEGER,
  ADD COLUMN IF NOT EXISTS calendar_name TEXT,
  ADD COLUMN IF NOT EXISTS group_task TEXT,
  ADD COLUMN IF NOT EXISTS when_rule TEXT,
  ADD COLUMN IF NOT EXISTS share_when_rule TEXT,
  ADD COLUMN IF NOT EXISTS activity_description TEXT,
  ADD COLUMN IF NOT EXISTS revised_days INTEGER,
  ADD COLUMN IF NOT EXISTS default_status TEXT,
  ADD COLUMN IF NOT EXISTS auto_share_linked_page BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS sync_with_group_task BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS external_share_with JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN ops.tracking_plan_material_timeline.milestone_name IS 'Full milestone name from BeProduct (TaskDescription/actionDescription)';
COMMENT ON COLUMN ops.tracking_plan_material_timeline.milestone_short_name IS 'Short milestone name from BeProduct (ShortDescription/shortDescription)';
COMMENT ON COLUMN ops.tracking_plan_material_timeline.department IS 'Department responsible for this milestone';
COMMENT ON COLUMN ops.tracking_plan_material_timeline.milestone_page_name IS 'Associated page name (e.g., Lab Dip, Strike Off)';

-- ============================================================================
-- Create index for common query patterns
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_style_timeline_milestone_name 
  ON ops.tracking_plan_style_timeline(milestone_name);

CREATE INDEX IF NOT EXISTS idx_style_timeline_department 
  ON ops.tracking_plan_style_timeline(department);

CREATE INDEX IF NOT EXISTS idx_material_timeline_milestone_name 
  ON ops.tracking_plan_material_timeline(milestone_name);

CREATE INDEX IF NOT EXISTS idx_material_timeline_department 
  ON ops.tracking_plan_material_timeline(department);
