-- Migration: 012_create_tracking_plan_dependencies.sql
-- Purpose: Create table to store tracking plan dependencies fetched from Lindy.ai
-- Context: Dependencies are scraped from BeProduct UI since there's no API access.
--          Each plan has a dependency chain that determines the critical path.

BEGIN;

CREATE TABLE ops.tracking_plan_dependencies (
    id BIGSERIAL PRIMARY KEY,
    plan_id UUID NOT NULL REFERENCES ops.tracking_plan(id) ON DELETE CASCADE,
    
    -- Dependency fields from Lindy
    row_number INTEGER NOT NULL,
    department TEXT,
    action_description TEXT NOT NULL,
    short_description TEXT,
    share_with TEXT,
    page TEXT,
    days INTEGER,
    depends_on TEXT,
    duration INTEGER,
    duration_unit TEXT,
    relationship TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure unique row numbers per plan
    UNIQUE(plan_id, row_number)
);

-- Index for lookups
CREATE INDEX idx_tracking_plan_dependencies_plan_id ON ops.tracking_plan_dependencies(plan_id);
CREATE INDEX idx_tracking_plan_dependencies_depends_on ON ops.tracking_plan_dependencies(plan_id, depends_on);

-- Comments
COMMENT ON TABLE ops.tracking_plan_dependencies IS 
    'Stores dependency chain for tracking plan milestones. Fetched via Lindy.ai webhook from BeProduct UI.';

COMMENT ON COLUMN ops.tracking_plan_dependencies.row_number IS 
    'Sequential order of the dependency. Row 0 = START DATE, Row 99 = END DATE';

COMMENT ON COLUMN ops.tracking_plan_dependencies.depends_on IS 
    'The action_description this step depends on. NULL for START DATE.';

COMMENT ON COLUMN ops.tracking_plan_dependencies.relationship IS 
    'Dependency type: start-to-start, end-to-start, start-to-end';

COMMIT;
