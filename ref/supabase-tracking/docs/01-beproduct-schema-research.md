# BeProduct Tracking Schema Research (GREYSON Pilot)

**Document version:** 0.1 • **Last updated:** 2025-10-22 • **Source:** MCP `beproduct-tracking` tool responses

## 1. Tracking folders

- **Endpoint:** `beproduct-tracking.folderList`
- **Folder of interest:** `GREYSON MENS`
  - `id`: `136625d5-d9cc-4139-8747-d98b85314676`
  - `name`: `GREYSON MENS`
  - `styleFolder.id`: `66f377be-d3d6-4e42-b50a-b46f4e156191` (TEST-GREYSON)
  - `styleFolder.name`: `TEST-GREYSON`
  - Additional attributes observed: `brand`, `season`, `createdDate`, `createdBy`, `updatedDate`, `updatedBy`, `active`
- Other folders in response (for cross-brand awareness): POLO, FITZ, G4, etc. All share similar structure.

## 2. Plans inside GREYSON folder

- **Endpoint:** `beproduct-tracking.planSearch`
- Request: `{ "folderId": "136625d5-d9cc-4139-8747-d98b85314676" }`
- **Plans retrieved:**
  | Plan name | Plan ID | Views | Active |
  | --- | --- | --- | --- |
  | GREYSON 2026 SPRING DROP 1 | `162eedf3-0230-4e4c-88e1-6db332e3707b` | Style, Material | true |
  | GREYSON 2026 SPRING DROP 2 | `ece9be3a-9c60-47d7-923c-a0af83e77a98` | Style, Material | true |
  | GREYSON 2026 SPRING DROP 3 | `35d05905-fce7-424f-916b-2348c2d4c77f` | Style, Material | true |
  | GREYSON W/ SAMPLE TRACKET | `85602834-cc81-4cb2-8d0d-72776db81fee` | Style, Material | true |
  | xxSPRING 2026 | `03accce8-ce7d-4c12-8791-ec211dd2f02e` | Style | false |
- **Plan object fields observed:**
  - `id`, `name`, `folderId`, `active`, `createdBy`, `createdDate`, `updatedBy`, `updatedDate`
  - `planViews`: array of view metadata with `id`, `name`, `type` (`style`/`material`), `active`, `sortOrder`, `templateId`
  - `startDate`, `endDate`, `season`, `brand`, `description`
  - `templateName`: e.g., `GREYSON MENS MASTER TIMELINE`
  - `timezone`, `colorTheme`, `defaultView`

## 3. Style timeline payload

- **Endpoint:** `beproduct-tracking.planStyleTimeline`
- Request sample: `{ "planId": "162eedf3-0230-4e4c-88e1-6db332e3707b" }`
- **Structure:**
  - Top-level object includes `plan`, `views`, `styles`, `timelineTemplates`, `meta`
  - `styles`: array of style entries (per style-color, per supplier). Sample fields:
    - `id` (timeline entry id), `styleId`, `styleHeaderId`, `colorId`, `supplierId`
    - `styleNumber`, `styleName`, `colorName`, `season`, `delivery`, `factory`, `brand`
    - `assignments`: array of user IDs / names (`assignedTo` objects with `id`, `name`, `email`, `roleId`)
    - `timeline`: array of milestones. Each milestone sample fields:
      - `id` (milestone record id)
      - `templateId`, `templateItemId`
      - `name`, `description`, `department`
      - `status` (string)
      - `planDate`, `revDate`, `finalDate`, `dueDate`
      - `completedDate`, `late` (boolean)
      - `notes`
      - `page`: object when linked to another BeProduct page (fields: `type`, `name`, `id`, `url`)
      - `request`: sample for sample requests with `id`, `code`, `status`
      - `assignedTo`: array of assignees (subset of `assignments` with `role` info)
      - `attachments`: list of file references (`id`, `name`, `url`)
      - `dependencies`: array referencing other milestone IDs
      - `timelineType`: typically `style`
  - `timelineTemplates`: includes hierarchical metadata per template item:
    - `id`, `name`, `type` (`master`, `style`, `material`), `items`
    - `items`: `id`, `name`, `displayOrder`, `defaultOffset`, `defaultDuration`, `department`, `appliesToStyle`, `appliesToMaterial`, `pageType`, `pageSubtype`
  - `meta.statuses`: array of available statuses (strings). Observed values: `Not Started`, `In Progress`, `Approved`, `Rejected`.

## 4. Material timeline payload

- **Endpoint:** `beproduct-tracking.planMaterialTimeline`
- Structure parallels style timeline with material-specific fields:
  - `materials`: array with fields like:
    - `id`, `materialId`, `materialHeaderId`, `colorId`, `materialNumber`, `materialName`, `color`, `supplier`, `bomItemId`
    - `styleLinks`: referencing styles that consume the material
    - `timeline`: milestone array identical in structure to style timeline but with `timelineType = material`
  - `timelineTemplates`: same collection as style timeline (shared master template), but items include `appliesToMaterial` toggles.

## 5. Enumerations & codes observed

- **Status strings:** `Not Started`, `In Progress`, `Approved`, `Rejected`
- **Department strings:** `DEVELOPMENT | PD`, `DEVELOPMENT | TECH DESIGN`, `PRODUCTION | FACTORY`, `PRODUCTION | INTERNAL`, `LOGISTICS | SHIPPING`, `DEVELOPMENT | FABRIC`, `SALES | SALES OPS`, `CREATIVE | DESIGN`
- **Page types:** `BOM`, `Form`, `SampleRequestMulti`, `SampleRequest`, `TechPack`
- **Timeline types:** `style`, `material`
- **Template types:** `master`, `style`, `material`

## 6. Field mapping considerations

- **Identifiers:** All major objects use UUIDs. We must persist these verbatim in Supabase to maintain referential integrity and allow re-syncing.
- **Dates:** Delivered as ISO strings; many milestones supply `null` for optional fields. We should use Postgres `timestamptz` with `NULL` defaults.
- **Assignments:** Users are represented by objects with `id`, `name`, `email`, `roleId`, `roleName`. No central user endpoint was queried yet; consider separate lookup.
- **Dependencies:** Provided as ID references; need junction table to store `predecessor_id` ↔ `successor_id` relationships.
- **Attachments:** Provided with `url` and `fileId`. Determine storage strategy (refer to BeProduct vs re-hosted files).
- **Late flag:** Derived from comparison of `dueDate` vs `finalDate` / `completedDate`. We can compute in SQL but storing raw boolean is acceptable for parity.

## 7. Follow-up data pulls

| Endpoint | Purpose |
| --- | --- |
| `planStyleView` | Retrieve column configuration, filters used by BeProduct front-end |
| `planMaterialView` | Same for material view |
| `planStyleProgress` | Summary metrics by status (to match dashboards) |
| `planMaterialProgress` | Material-specific progress stats |
| `planAddStyle` / `planAddMaterial` | Understand payload when creating new entries |
| `planUpdateStyleTimelines` | Understand mutation contract for timeline updates |

The above will help finalize Supabase mutation design and ensure we cover all metadata.

## 8. Outstanding questions for BeProduct

1. Are there hidden statuses or department values available via master data endpoints?
2. Do timeline templates differ per plan view, or is there a shared master template with toggles (current data suggests shared)?
3. What triggers the `late` flag—strict due date vs final date vs actual completion date? Needed for parity logic.
4. Are attachments accessible long-term via provided URLs, or do they require authenticated retrieval?
5. How are role IDs managed? (We currently only see `roleId` numbers; need mapping for Supabase import.)