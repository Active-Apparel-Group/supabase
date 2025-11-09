-- Migration: Import Garment Tracking Timeline Template (Simplified for Supabase)
-- Description: Imports the existing "Garment Tracking Timeline" template with 26 nodes
-- This version uses a CTE to avoid psql variable issues

WITH template_insert AS (
    INSERT INTO tracking.timeline_templates (
        id,
        name,
        description,
        category,
        is_default,
        is_active,
        metadata,
        created_by,
        created_at,
        modified_by,
        modified_at
    ) VALUES (
        gen_random_uuid(),
        'Garment Tracking Timeline',
        'Comprehensive tracking timeline covering development, SMS, production allocation, and logistics phases',
        'Garment Production',
        true,
        true,
        jsonb_build_object(
            'version', '1.0',
            'plan_config', jsonb_build_object(
                'timezone', 'Australia/Brisbane',
                'anchor_strategy', 'bookend',
                'start_date', null,
                'end_date', null,
                'business_day_calendar', jsonb_build_object(
                    'weekends', jsonb_build_array('SATURDAY', 'SUNDAY'),
                    'holidays', jsonb_build_array()
                ),
                'conflict_policy', 'report',
                'notes', 'Provide start_date and end_date; offsets are calculated from these anchors.'
            ),
            'source', 'migration_from_beproduct',
            'original_timeline_name', 'Garment Tracking Timeline'
        ),
        (SELECT id FROM public.user LIMIT 1),
        NOW(),
        (SELECT id FROM public.user LIMIT 1),
        NOW()
    )
    RETURNING id as template_id
)
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
)
SELECT 
    gen_random_uuid(),
    template_insert.template_id,
    t.sequence_number,
    t.node_type,
    t.phase,
    t.department,
    t.action_description,
    t.short_description,
    t.page_reference,
    t.dependency_node_sequence,
    t.dependency_relation,
    t.offset_value,
    t.offset_unit,
    t.visibility_config,
    t.is_active,
    t.metadata
FROM template_insert
CROSS JOIN (VALUES
    -- ANCHOR NODES
    (0, 'ANCHOR', 'PLAN', 'SYSTEM', 'START DATE', 'START DATE', NULL, NULL, NULL, 0, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 0)),
    (99, 'ANCHOR', 'PLAN', 'SYSTEM', 'END DATE', 'END DATE', NULL, NULL, NULL, 0, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 99)),
    
    -- DEVELOPMENT PHASE
    (1, 'TASK', 'DEVELOPMENT', 'CUSTOMER', 'TECHPACKS PASS OFF', 'TECHPACKS PASS OFF', 'Production BoM', 0, 'AFTER', 0, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 1, 'depends_on_action', 'START DATE')),
    (2, 'TASK', 'DEVELOPMENT', 'PD', 'PROTO PRODUCTION', 'PROTO PRODUCTION', NULL, 1, 'AFTER', 4, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 2, 'depends_on_action', 'TECHPACKS PASS OFF')),
    (3, 'TASK', 'DEVELOPMENT', 'PD', 'PROTO EX-FCTY', 'PROTO EX-FCTY', 'Proto Sample', 2, 'AFTER', 14, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 3, 'depends_on_action', 'PROTO PRODUCTION')),
    (4, 'TASK', 'DEVELOPMENT', 'ACCOUNT MANAGER', 'PROTO COSTING DUE', 'PROTO COSTING DUE', 'Production BoM', 3, 'AFTER', 2, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 4, 'depends_on_action', 'PROTO EX-FCTY')),
    (5, 'TASK', 'DEVELOPMENT', 'CUSTOMER', 'PROTO FIT COMMENTS DUE', 'PROTO FIT COMMENTS DUE', 'Proto Sample', 3, 'AFTER', 21, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 5, 'depends_on_action', 'PROTO EX-FCTY')),
    (6, 'TASK', 'DEVELOPMENT', 'PD', '2nd PROTO PRODUCTION', '2nd PROTO PRODUCTION', NULL, 5, 'AFTER', 4, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 6, 'depends_on_action', 'PROTO FIT COMMENTS DUE')),
    (7, 'TASK', 'DEVELOPMENT', 'PD', '2nd PROTO EX-FCTY', '2nd PROTO EX-FCTY', 'Fit Sample', 6, 'AFTER', 14, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 7, 'depends_on_action', '2nd PROTO PRODUCTION')),
    (8, 'TASK', 'DEVELOPMENT', 'CUSTOMER', '2nd PROTO FIT COMMENTS DUE', '2nd PROTO FIT COMMENTS DUE', 'Fit Sample', 7, 'AFTER', 21, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 8, 'depends_on_action', '2nd PROTO EX-FCTY')),
    
    -- SMS PHASE
    (9, 'TASK', 'SMS', 'CUSTOMER', 'SMS POs PLACED', 'SMS POs PLACED', NULL, 1, 'AFTER', 3, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 9, 'depends_on_action', 'TECHPACKS PASS OFF')),
    (10, 'TASK', 'SMS', 'PD', 'SMS EX-FCTY', 'SMS EX-FCTY', 'Fit Sample', 9, 'AFTER', 106, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 10, 'depends_on_action', 'SMS POs PLACED')),
    
    -- PRODUCTION PHASE
    (11, 'TASK', 'PRODUCTION', 'CUSTOMER', 'BULK PO', 'BULK PO', NULL, 20, 'BEFORE', -74, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 11, 'depends_on_action', 'PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE')),
    (20, 'TASK', 'PRODUCTION', 'CUSTOMER', 'PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE', 'PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE', NULL, 23, 'BEFORE', -60, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 20, 'depends_on_action', 'CUT DATE')),
    (21, 'TASK', 'PRODUCTION', 'PURCHASING', 'BULK FABRIC & TRIM IN-HOUSE', 'BULK FABRIC & TRIM IN-HOUSE', NULL, 23, 'BEFORE', -30, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 21, 'depends_on_action', 'CUT DATE')),
    (22, 'TASK', 'PRODUCTION', 'CUSTOMER', 'PPS APPROVAL', 'PPS APPROVAL', 'PP Sample', 23, 'BEFORE', -10, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 22, 'depends_on_action', 'CUT DATE')),
    (23, 'TASK', 'PRODUCTION', 'FACTORY', 'CUT DATE', 'CUT DATE', NULL, 24, 'BEFORE', -60, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 23, 'depends_on_action', 'EX-FTY DATE')),
    (24, 'TASK', 'PRODUCTION', 'FACTORY', 'EX-FTY DATE', 'EX-FTY DATE', NULL, 99, 'BEFORE', -30, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 24, 'depends_on_action', 'END DATE')),
    (25, 'TASK', 'PRODUCTION', 'LOGISTICS', 'IN WAREHOUSE', 'IN WAREHOUSE', NULL, 99, 'AFTER', 0, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 25, 'depends_on_action', 'END DATE')),
    
    -- ALLOCATION PHASE
    (12, 'TASK', 'ALLOCATION', 'CFT', 'Issue partner allocations', 'Issue partner allocations', 'Sourcing and Delivery', 11, 'AFTER', 2, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 12, 'depends_on_action', 'BULK PO')),
    (13, 'TASK', 'ALLOCATION', 'FACTORY', 'Download Tech Packs', 'Download Tech Packs', 'Tech Pack', 11, 'AFTER', 4, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 13, 'depends_on_action', 'BULK PO')),
    (14, 'TASK', 'ALLOCATION', 'CFT', 'Physical Reference Samples', 'Physical Reference Samples', 'Sourcing and Delivery', 11, 'AFTER', 4, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 14, 'depends_on_action', 'BULK PO')),
    (15, 'TASK', 'ALLOCATION', 'FINANCE', 'Confirm target CMP price', 'Confirm target price', 'Sourcing and Delivery', 11, 'AFTER', 4, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 15, 'depends_on_action', 'BULK PO')),
    (16, 'TASK', 'ALLOCATION', 'FACTORY', 'Submit confirmed pricing and ex-factory date', 'Submit confirmed pricing and ex-factory date', 'Sourcing and Delivery', 13, 'AFTER', 8, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 16, 'depends_on_action', 'Download Tech Packs')),
    (17, 'TASK', 'ALLOCATION', 'ACCOUNT MANAGER', 'Approve terms and price', 'Approve terms and price', NULL, 16, 'AFTER', 3, 'DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 17, 'depends_on_action', 'Submit confirmed pricing and ex-factory date')),
    (18, 'TASK', 'ALLOCATION', 'CFT', 'Issue purchase contract to factory', 'Issue purchase contract to factory', NULL, 17, 'AFTER', 2, 'BUSINESS_DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 18, 'depends_on_action', 'Approve terms and price')),
    (19, 'TASK', 'ALLOCATION', 'FACTORY', 'Countersign Purchase Contract', 'Countersign Purchase Contract', NULL, 18, 'AFTER', 6, 'BUSINESS_DAYS', jsonb_build_object('share_with', NULL), true, jsonb_build_object('original_id', 19, 'depends_on_action', 'Issue purchase contract to factory'))
) AS t(
    sequence_number, node_type, phase, department, action_description, short_description,
    page_reference, dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
);
