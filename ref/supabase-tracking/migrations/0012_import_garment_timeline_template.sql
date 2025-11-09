-- Migration: Import Garment Tracking Timeline Template
-- Description: Imports the existing "Garment Tracking Timeline" template with 26 nodes
-- Author: System Migration
-- Date: 2025-10-23

-- =============================================================================
-- STEP 1: Insert Timeline Template Header
-- =============================================================================

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
    true, -- Set as default template
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
    (SELECT user_id FROM tracking.user LIMIT 1), -- Use first available user
    NOW(),
    (SELECT user_id FROM tracking.user LIMIT 1),
    NOW()
)
RETURNING id AS template_id
\gset

-- Store template_id in a variable for subsequent inserts
-- Note: Replace :template_id with the actual UUID returned above when running manually

-- =============================================================================
-- STEP 2: Insert Timeline Template Items (Nodes)
-- =============================================================================

-- ANCHOR NODES (START & END)

-- Node 0: START DATE (ANCHOR)
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 0, 'ANCHOR', 'PLAN', 'SYSTEM',
    'START DATE', 'START DATE', NULL,
    NULL, NULL, 0, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 0, 'computed_date', NULL)
);

-- Node 99: END DATE (ANCHOR)
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 99, 'ANCHOR', 'PLAN', 'SYSTEM',
    'END DATE', 'END DATE', NULL,
    NULL, NULL, 0, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 99, 'computed_date', NULL)
);

-- DEVELOPMENT PHASE

-- Node 1: TECHPACKS PASS OFF
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 1, 'TASK', 'DEVELOPMENT', 'CUSTOMER',
    'TECHPACKS PASS OFF', 'TECHPACKS PASS OFF', 'Production BoM',
    0, 'AFTER', 0, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 1, 'depends_on_action', 'START DATE')
);

-- Node 2: PROTO PRODUCTION
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 2, 'TASK', 'DEVELOPMENT', 'PD',
    'PROTO PRODUCTION', 'PROTO PRODUCTION', NULL,
    1, 'AFTER', 4, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 2, 'depends_on_action', 'TECHPACKS PASS OFF')
);

-- Node 3: PROTO EX-FCTY
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 3, 'TASK', 'DEVELOPMENT', 'PD',
    'PROTO EX-FCTY', 'PROTO EX-FCTY', 'Proto Sample',
    2, 'AFTER', 14, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 3, 'depends_on_action', 'PROTO PRODUCTION')
);

-- Node 4: PROTO COSTING DUE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 4, 'TASK', 'DEVELOPMENT', 'ACCOUNT MANAGER',
    'PROTO COSTING DUE', 'PROTO COSTING DUE', 'Production BoM',
    3, 'AFTER', 2, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 4, 'depends_on_action', 'PROTO EX-FCTY')
);

-- Node 5: PROTO FIT COMMENTS DUE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 5, 'TASK', 'DEVELOPMENT', 'CUSTOMER',
    'PROTO FIT COMMENTS DUE', 'PROTO FIT COMMENTS DUE', 'Proto Sample',
    3, 'AFTER', 21, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 5, 'depends_on_action', 'PROTO EX-FCTY')
);

-- Node 6: 2nd PROTO PRODUCTION
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 6, 'TASK', 'DEVELOPMENT', 'PD',
    '2nd PROTO PRODUCTION', '2nd PROTO PRODUCTION', NULL,
    5, 'AFTER', 4, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 6, 'depends_on_action', 'PROTO FIT COMMENTS DUE')
);

-- Node 7: 2nd PROTO EX-FCTY
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 7, 'TASK', 'DEVELOPMENT', 'PD',
    '2nd PROTO EX-FCTY', '2nd PROTO EX-FCTY', 'Fit Sample',
    6, 'AFTER', 14, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 7, 'depends_on_action', '2nd PROTO PRODUCTION')
);

-- Node 8: 2nd PROTO FIT COMMENTS DUE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 8, 'TASK', 'DEVELOPMENT', 'CUSTOMER',
    '2nd PROTO FIT COMMENTS DUE', '2nd PROTO FIT COMMENTS DUE', 'Fit Sample',
    7, 'AFTER', 21, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 8, 'depends_on_action', '2nd PROTO EX-FCTY')
);

-- SMS PHASE

-- Node 9: SMS POs PLACED
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 9, 'TASK', 'SMS', 'CUSTOMER',
    'SMS POs PLACED', 'SMS POs PLACED', NULL,
    1, 'AFTER', 3, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 9, 'depends_on_action', 'TECHPACKS PASS OFF')
);

-- Node 10: SMS EX-FCTY
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 10, 'TASK', 'SMS', 'PD',
    'SMS EX-FCTY', 'SMS EX-FCTY', 'Fit Sample',
    9, 'AFTER', 106, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 10, 'depends_on_action', 'SMS POs PLACED')
);

-- PRODUCTION PHASE

-- Node 11: BULK PO
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 11, 'TASK', 'PRODUCTION', 'CUSTOMER',
    'BULK PO', 'BULK PO', NULL,
    20, 'BEFORE', -74, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 11, 'depends_on_action', 'PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE')
);

-- ALLOCATION PHASE

-- Node 12: Issue partner allocations
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 12, 'TASK', 'ALLOCATION', 'CFT',
    'Issue partner allocations', 'Issue partner allocations', 'Sourcing and Delivery',
    11, 'AFTER', 2, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 12, 'depends_on_action', 'BULK PO')
);

-- Node 13: Download Tech Packs
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 13, 'TASK', 'ALLOCATION', 'FACTORY',
    'Download Tech Packs', 'Download Tech Packs', 'Tech Pack',
    11, 'AFTER', 4, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 13, 'depends_on_action', 'BULK PO')
);

-- Node 14: Physical Reference Samples
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 14, 'TASK', 'ALLOCATION', 'CFT',
    'Physical Reference Samples', 'Physical Reference Samples', 'Sourcing and Delivery',
    11, 'AFTER', 4, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 14, 'depends_on_action', 'BULK PO')
);

-- Node 15: Confirm target CMP price
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 15, 'TASK', 'ALLOCATION', 'FINANCE',
    'Confirm target CMP price', 'Confirm target price', 'Sourcing and Delivery',
    11, 'AFTER', 4, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 15, 'depends_on_action', 'BULK PO')
);

-- Node 16: Submit confirmed pricing and ex-factory date
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 16, 'TASK', 'ALLOCATION', 'FACTORY',
    'Submit confirmed pricing and ex-factory date', 'Submit confirmed pricing and ex-factory date', 'Sourcing and Delivery',
    13, 'AFTER', 8, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 16, 'depends_on_action', 'Download Tech Packs')
);

-- Node 17: Approve terms and price
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 17, 'TASK', 'ALLOCATION', 'ACCOUNT MANAGER',
    'Approve terms and price', 'Approve terms and price', NULL,
    16, 'AFTER', 3, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 17, 'depends_on_action', 'Submit confirmed pricing and ex-factory date')
);

-- Node 18: Issue purchase contract to factory
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 18, 'TASK', 'ALLOCATION', 'CFT',
    'Issue purchase contract to factory', 'Issue purchase contract to factory', NULL,
    17, 'AFTER', 2, 'BUSINESS_DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 18, 'depends_on_action', 'Approve terms and price')
);

-- Node 19: Countersign Purchase Contract
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 19, 'TASK', 'ALLOCATION', 'FACTORY',
    'Countersign Purchase Contract', 'Countersign Purchase Contract', NULL,
    18, 'AFTER', 6, 'BUSINESS_DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 19, 'depends_on_action', 'Issue purchase contract to factory')
);

-- Node 20: PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 20, 'TASK', 'PRODUCTION', 'CUSTOMER',
    'PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE', 'PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE', NULL,
    23, 'BEFORE', -60, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 20, 'depends_on_action', 'CUT DATE')
);

-- Node 21: BULK FABRIC & TRIM IN-HOUSE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 21, 'TASK', 'PRODUCTION', 'PURCHASING',
    'BULK FABRIC & TRIM IN-HOUSE', 'BULK FABRIC & TRIM IN-HOUSE', NULL,
    23, 'BEFORE', -30, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 21, 'depends_on_action', 'CUT DATE')
);

-- Node 22: PPS APPROVAL
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 22, 'TASK', 'PRODUCTION', 'CUSTOMER',
    'PPS APPROVAL', 'PPS APPROVAL', 'PP Sample',
    23, 'BEFORE', -10, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 22, 'depends_on_action', 'CUT DATE')
);

-- Node 23: CUT DATE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 23, 'TASK', 'PRODUCTION', 'FACTORY',
    'CUT DATE', 'CUT DATE', NULL,
    24, 'BEFORE', -60, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 23, 'depends_on_action', 'EX-FTY DATE')
);

-- Node 24: EX-FTY DATE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 24, 'TASK', 'PRODUCTION', 'FACTORY',
    'EX-FTY DATE', 'EX-FTY DATE', NULL,
    99, 'BEFORE', -30, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 24, 'depends_on_action', 'END DATE')
);

-- Node 25: IN WAREHOUSE
INSERT INTO tracking.timeline_template_items (
    id, template_id, sequence_number, node_type, phase, department,
    action_description, short_description, page_reference,
    dependency_node_sequence, dependency_relation, offset_value, offset_unit,
    visibility_config, is_active, metadata
) VALUES (
    gen_random_uuid(), :'template_id', 25, 'TASK', 'PRODUCTION', 'LOGISTICS',
    'IN WAREHOUSE', 'IN WAREHOUSE', NULL,
    99, 'AFTER', 0, 'DAYS',
    jsonb_build_object('share_with', NULL), true,
    jsonb_build_object('original_id', 25, 'depends_on_action', 'END DATE')
);

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Verify template was created
SELECT 
    id,
    name,
    category,
    is_default,
    is_active,
    created_at
FROM tracking.timeline_templates
WHERE name = 'Garment Tracking Timeline';

-- Verify all 26 items were created (2 anchors + 24 tasks)
SELECT 
    template_id,
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE node_type = 'ANCHOR') as anchor_count,
    COUNT(*) FILTER (WHERE node_type = 'TASK') as task_count,
    array_agg(DISTINCT phase ORDER BY phase) as phases
FROM tracking.timeline_template_items
WHERE template_id = :'template_id'
GROUP BY template_id;

-- View items by phase
SELECT 
    phase,
    COUNT(*) as item_count,
    array_agg(action_description ORDER BY sequence_number) as actions
FROM tracking.timeline_template_items
WHERE template_id = :'template_id'
GROUP BY phase
ORDER BY 
    CASE phase
        WHEN 'PLAN' THEN 1
        WHEN 'DEVELOPMENT' THEN 2
        WHEN 'SMS' THEN 3
        WHEN 'ALLOCATION' THEN 4
        WHEN 'PRODUCTION' THEN 5
    END;

-- =============================================================================
-- SUCCESS MESSAGE
-- =============================================================================
\echo ''
\echo '✅ Migration Complete!'
\echo '========================'
\echo 'Template imported: Garment Tracking Timeline'
\echo 'Total items: 26 (2 anchors + 24 tasks)'
\echo 'Phases covered: DEVELOPMENT, SMS, ALLOCATION, PRODUCTION'
\echo ''
\echo 'Next steps:'
\echo '1. Test endpoints: GET /rest/v1/v_timeline_template'
\echo '2. Test endpoints: GET /rest/v1/v_timeline_template_item'
\echo '3. Frontend can now view template data'
\echo ''
