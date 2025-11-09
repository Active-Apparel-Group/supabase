

---
Update: 7th November 2025

## 1. Core Table for Styles

**Table:** `ops.tracking_plan_style`

### Key Columns for Frontend
- `id`: Primary key for style record
- `plan_id`: Foreign key to the tracking plan
- `style_id`: BeProduct style header ID (if available)
- `style_number`, `style_name`, `color_id`, `color_name`: Style identifiers
- `season`, `delivery`, `factory`, `brand`: Contextual info
- `status_summary` (JSONB): **Holds all milestone/timeline data for this style**
- `suppliers` (JSONB): Array of supplier company IDs and roles (controls visibility/access)
- `active`: Boolean for soft delete
- `created_at`, `updated_at`: Timestamps for record management
- `raw_payload` (JSONB): Original BeProduct payload for audit/debug

---

## 2. Timeline/Milestone Data

### Where to Find Timeline Data
- **All milestone/timeline info is now in `status_summary` (JSONB) on each style record.**
- This replaces the old `tracking_plan_style_timeline` table.

### Example Structure for `status_summary`
```json
{
  "milestones": [
    {
      "name": "Design Complete",
      "short_name": "Design",
      "status": "Complete",
      "plan_date": "2025-11-01",
      "due_date": "2025-11-05",
      "completed_date": "2025-11-04",
      "notes": "Final design approved",
      "department": "PD",
      "phase": "DEVELOPMENT",
      "assigned_to": ["user-uuid-1"],
      "shared_with": ["supplier-uuid-1"],
      "duration_value": 4,
      "duration_unit": "DAYS"
    },
    {
      "name": "Proto Sample",
      "short_name": "Proto",
      "status": "In Progress",
      "plan_date": "2025-11-06",
      "due_date": "2025-11-10",
      "completed_date": null,
      "notes": "",
      "department": "PRODUCTION",
      "phase": "PRE-PRODUCTION",
      "assigned_to": ["user-uuid-2"],
      "shared_with": ["supplier-uuid-2"],
      "duration_value": 4,
      "duration_unit": "DAYS"
    }
    // ...more milestones
  ]
}
```
- **Frontend should read and write milestone data from/to this field.**
- All milestone fields (name, status, dates, notes, assignment, visibility, etc.) are included.

---

## 3. Supplier/User Visibility

- **Visibility and assignment for styles is controlled by:**
  - `suppliers` (array of company IDs/roles) for style-level access
  - `assigned_to` and `shared_with` inside each milestone in `status_summary` for per-milestone access

---

## 4. CRUD Operations

- **Create, update, delete styles** using the `tracking_plan_style` table.
- **Milestone/timeline updates** are handled by updating the `status_summary` JSONB field.
- **Soft delete** by setting `active` to false.

---

## 5. Example Queries

- **List all styles for a plan:**
  ```sql
  SELECT * FROM ops.tracking_plan_style WHERE plan_id = '<plan-uuid>' AND active = true;
  ```
- **Get milestones for a style:**
  ```sql
  SELECT status_summary FROM ops.tracking_plan_style WHERE id = '<style-uuid>';
  ```
- **Update milestone status:**
  - Update the relevant milestone object inside `status_summary` and write back to the style record.

---

## 6. Migration Notes

- **No more timeline tables for styles.**
- **All timeline/milestone data is in `status_summary` on the style record.**
- **Frontend should treat `status_summary` as the source of truth for all milestone/timeline info.**

---

## 7. What to Remove/Ignore

- Ignore any code or queries referencing `tracking_plan_style_timeline` or other timeline tables.
- Remove any frontend logic that expects timeline data outside of the style record.

---

## 8. What to Build/Update

- Update frontend models to read/write milestone data from `status_summary`.
- Update API calls to use only `tracking_plan_style` for style and milestone CRUD.
- Ensure supplier/user visibility logic uses the new fields.

---

**Summary:**  
All style and milestone/timeline data is now in `ops.tracking_plan_style`, with milestones stored in the `status_summary` JSONB field. Update your frontend to use this structure for all style-related displays, CRUD, and progress tracking.

If you need a sample API contract or more example queries, just ask!