-- Migration: 011_merge_tracking_folders.sql
-- Purpose: Consolidate duplicate tracking folder records and realign downstream references
-- Context: Earlier imports created a synthetic folder ID (82a6...) that pointed to the BeProduct folder (1366...).
--          The webhook now upserts using the real BeProduct folder ID. This migration moves existing data
--          to the canonical ID and removes the legacy record.
-- Note: tracking_folder_summary is a view that auto-updates, so we only need to modify the base tables.

BEGIN;

-- Step 1: Point all plans at the canonical folder ID (already done, but safe to re-run)
UPDATE ops.tracking_plan
SET folder_id = '136625d5-d9cc-4139-8747-d98b85314676'
WHERE folder_id = '82a698e1-9103-4bab-98af-a0ec423332a2';

-- Step 2: Copy folder metadata (style folder references) onto the canonical row
-- The canonical folder should reference itself as the style_folder_id
UPDATE ops.tracking_folder
SET style_folder_id = '136625d5-d9cc-4139-8747-d98b85314676',
    updated_at = NOW()
WHERE id = '136625d5-d9cc-4139-8747-d98b85314676';

-- Step 3: Delete the legacy folder record
-- This will automatically update the tracking_folder_summary view
DELETE FROM ops.tracking_folder
WHERE id = '82a698e1-9103-4bab-98af-a0ec423332a2';

COMMIT;
