# Timeline API Endpoint Design

**Purpose:** Unified REST API specification for timeline tracking  
**Status:** Ready for Implementation  
**Date:** October 31, 2025

---

## Design Principles

1. **Domain-Based Organization:** Endpoints grouped by business domain (tracking, style, material, color)
2. **Entity-Agnostic Core:** Timeline endpoints work across all entity types
3. **RESTful Conventions:** Standard HTTP methods, resource naming, status codes
4. **BeProduct Parity:** Same operations, enhanced with additional capabilities
5. **Performance First:** Efficient queries, pagination, caching support

---

## Base URL Structure

```
https://api.yourcompany.com/api/v1
├── /tracking          # Timeline tracking domain
├── /styles            # Style management domain
├── /materials         # Material management domain
├── /colors            # Color palette domain
└── /blocks            # Block/production domain (future)
```

---

## Tracking Domain Endpoints

### 1. Get Timeline for Entity

**Endpoint:** `GET /api/v1/tracking/timeline/{entity_type}/{entity_id}`

**Description:** Retrieve complete timeline for a specific entity (style, material, order, production)

**Path Parameters:**
- `entity_type` (string, required): Entity type enum [`style`, `material`, `order`, `production`]
- `entity_id` (UUID, required): Entity identifier

**Query Parameters:**
- `plan_id` (UUID, optional): Filter by specific plan
- `include_completed` (boolean, default: `true`): Include approved/NA milestones
- `include_dependencies` (boolean, default: `false`): Include dependency relationships
- `include_assignments` (boolean, default: `true`): Include assigned users
- `include_sharing` (boolean, default: `true`): Include shared users

**Response:** `200 OK`
```json
{
  "entity_type": "style",
  "entity_id": "style-uuid",
  "entity_name": "MONTAUK SHORT - 8\" INSEAM",
  "colorway_id": "colorway-uuid",
  "colorway_name": "220 - GROVE",
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "timeline": [
    {
      "node_id": "node-uuid",
      "milestone_id": "template-milestone-uuid",
      "milestone_name": "TECHPACKS PASS OFF",
      "phase": "DEVELOPMENT",
      "department": "DESIGN",
      "status": "approved",
      "plan_date": "2025-05-01",
      "rev_date": null,
      "due_date": "2025-05-01",
      "final_date": "2025-05-01",
      "start_date_plan": "2025-04-28",
      "start_date_due": "2025-04-28",
      "is_late": false,
      "assigned_to": [],
      "shared_with": [],
      "page": {
        "id": "page-uuid",
        "title": "Techpack",
        "type": "techpack"
      },
      "customer_visible": true,
      "supplier_visible": false,
      "submits_quantity": 0,
      "dependencies": [
        {
          "predecessor_node_id": "start-node-uuid",
          "predecessor_milestone": "START DATE",
          "dependency_type": "finish_to_start",
          "lag_days": 0
        }
      ],
      "created_at": "2025-05-01T10:00:00Z",
      "updated_at": "2025-05-01T15:30:00Z"
    }
    // ... more milestones
  ],
  "metadata": {
    "total_milestones": 25,
    "completed_milestones": 5,
    "late_milestones": 10,
    "completion_percentage": 20.0
  }
}
```

**Error Responses:**
- `404 Not Found`: Entity or plan not found
- `400 Bad Request`: Invalid entity_type

**Equivalent BeProduct:** `planStyleTimeline`, `planMaterialTimeline`

---

### 2. Get Plan Timeline (All Entities)

**Endpoint:** `GET /api/v1/tracking/plans/{plan_id}/timeline`

**Description:** Retrieve complete timeline for entire plan (all styles, materials, etc.)

**Path Parameters:**
- `plan_id` (UUID, required): Plan identifier

**Query Parameters:**
- `entity_type` (string, optional): Filter by entity type
- `status` (string, optional): Filter by status [`not_started`, `in_progress`, `approved`, etc.]
- `late_only` (boolean, default: `false`): Show only late milestones
- `page` (integer, default: `1`): Page number for pagination
- `page_size` (integer, default: `50`): Items per page

**Response:** `200 OK`
```json
{
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "start_date": "2025-05-01",
  "end_date": "2026-01-05",
  "timeline": [
    {
      "node_id": "node-uuid",
      "entity_type": "style",
      "entity_id": "style-uuid",
      "entity_name": "MONTAUK SHORT - 8\" INSEAM",
      "colorway_name": "220 - GROVE",
      "milestone_name": "PROTO PRODUCTION",
      "status": "in_progress",
      "due_date": "2025-09-16",
      "is_late": true,
      "assigned_to": [
        {
          "id": "user-uuid",
          "name": "Natalie James",
          "email": "natalie@example.com"
        }
      ]
    }
    // ... more milestones
  ],
  "pagination": {
    "page": 1,
    "page_size": 50,
    "total_items": 125,
    "total_pages": 3
  }
}
```

---

### 3. Get Plan Progress

**Endpoint:** `GET /api/v1/tracking/plans/{plan_id}/progress`

**Description:** Retrieve status summary for plan

**Path Parameters:**
- `plan_id` (UUID, required): Plan identifier

**Query Parameters:**
- `entity_type` (string, optional): Filter by entity type
- `group_by` (string, optional): Group by field [`phase`, `department`, `entity_type`]

**Response:** `200 OK`
```json
{
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "total_milestones": 125,
  "by_status": {
    "not_started": 109,
    "in_progress": 11,
    "waiting_on": 0,
    "rejected": 0,
    "approved": 5,
    "approved_with_corrections": 0,
    "na": 0
  },
  "late_count": 110,
  "on_time_count": 15,
  "completion_percentage": 4.0,
  "by_entity_type": {
    "style": {
      "total": 75,
      "late": 65,
      "completed": 5,
      "completion_percentage": 6.67
    },
    "material": {
      "total": 50,
      "late": 45,
      "completed": 0,
      "completion_percentage": 0.0
    }
  },
  "by_phase": {
    "DEVELOPMENT": {
      "total": 50,
      "late": 40,
      "completed": 5
    },
    "SMS": {
      "total": 30,
      "late": 25,
      "completed": 0
    }
    // ... more phases
  }
}
```

**Equivalent BeProduct:** `planStyleProgress`, `planMaterialProgress`

---

### 4. Update Timeline Milestones (Bulk)

**Endpoint:** `PATCH /api/v1/tracking/timeline/bulk`

**Description:** Update multiple milestones in a single request

**Request Body:**
```json
{
  "updates": [
    {
      "node_id": "node-uuid-1",
      "status": "in_progress",
      "rev_date": "2025-11-15",
      "updated_by": "user-uuid"
    },
    {
      "node_id": "node-uuid-2",
      "final_date": "2025-11-01",
      "status": "approved",
      "updated_by": "user-uuid"
    },
    {
      "node_id": "node-uuid-3",
      "status": "na",
      "updated_by": "user-uuid"
    }
  ]
}
```

**Response:** `200 OK`
```json
{
  "updated_count": 3,
  "recalculated_count": 12,
  "updates": [
    {
      "node_id": "node-uuid-1",
      "old_status": "not_started",
      "new_status": "in_progress",
      "old_due_date": "2025-11-10",
      "new_due_date": "2025-11-15",
      "downstream_affected": 5
    },
    {
      "node_id": "node-uuid-2",
      "old_status": "in_progress",
      "new_status": "approved",
      "old_due_date": "2025-11-05",
      "new_due_date": "2025-11-01",
      "downstream_affected": 7
    },
    {
      "node_id": "node-uuid-3",
      "old_status": "not_started",
      "new_status": "na",
      "downstream_affected": 0
    }
  ]
}
```

**Error Responses:**
- `400 Bad Request`: Invalid node_id or status value
- `404 Not Found`: Node not found
- `409 Conflict`: Concurrent update conflict

**Equivalent BeProduct:** `planUpdateStyleTimelines`, `planUpdateMaterialTimelines`

**Enhancement:** Auto-recalculation for `rev_date` changes (BeProduct gap fixed!)

---

### 5. Update Single Milestone

**Endpoint:** `PATCH /api/v1/tracking/timeline/node/{node_id}`

**Description:** Update a single milestone

**Path Parameters:**
- `node_id` (UUID, required): Timeline node identifier

**Request Body:**
```json
{
  "status": "approved",
  "final_date": "2025-11-01",
  "updated_by": "user-uuid"
}
```

**Response:** `200 OK`
```json
{
  "node_id": "node-uuid",
  "milestone_name": "PROTO PRODUCTION",
  "old_status": "in_progress",
  "new_status": "approved",
  "old_due_date": "2025-11-05",
  "new_due_date": "2025-11-01",
  "final_date": "2025-11-01",
  "is_late": false,
  "downstream_affected": 7,
  "updated_at": "2025-11-01T16:30:00Z"
}
```

---

### 6. Assign User to Milestone

**Endpoint:** `POST /api/v1/tracking/timeline/node/{node_id}/assignments`

**Description:** Assign a user to a milestone

**Path Parameters:**
- `node_id` (UUID, required): Timeline node identifier

**Request Body:**
```json
{
  "user_id": "user-uuid",
  "assigned_by": "manager-user-uuid"
}
```

**Response:** `201 Created`
```json
{
  "assignment_id": "assignment-uuid",
  "node_id": "node-uuid",
  "user_id": "user-uuid",
  "user_name": "Natalie James",
  "assigned_at": "2025-11-01T10:00:00Z",
  "assigned_by": "manager-user-uuid"
}
```

---

### 7. Share Milestone with User

**Endpoint:** `POST /api/v1/tracking/timeline/node/{node_id}/sharing`

**Description:** Share a milestone with a user (visibility)

**Path Parameters:**
- `node_id` (UUID, required): Timeline node identifier

**Request Body:**
```json
{
  "user_id": "user-uuid",
  "shared_by": "manager-user-uuid"
}
```

**Response:** `201 Created`
```json
{
  "share_id": "share-uuid",
  "node_id": "node-uuid",
  "user_id": "user-uuid",
  "user_name": "Chris K",
  "shared_at": "2025-11-01T10:00:00Z",
  "shared_by": "manager-user-uuid"
}
```

---

### 8. Get User Workload

**Endpoint:** `GET /api/v1/tracking/users/{user_id}/assignments`

**Description:** Get all assigned milestones for a user across all plans

**Path Parameters:**
- `user_id` (UUID, required): User identifier

**Query Parameters:**
- `status` (string, optional): Filter by status
- `late_only` (boolean, default: `false`): Show only late milestones
- `plan_id` (UUID, optional): Filter by plan

**Response:** `200 OK`
```json
{
  "user_id": "user-uuid",
  "user_name": "Natalie James",
  "user_email": "natalie@example.com",
  "assignments": [
    {
      "node_id": "node-uuid-1",
      "entity_type": "style",
      "entity_name": "MONTAUK SHORT - 8\" INSEAM",
      "plan_name": "GREYSON 2026 SPRING DROP 1",
      "milestone_name": "PROTO PRODUCTION",
      "status": "in_progress",
      "due_date": "2025-11-05",
      "is_late": true,
      "assigned_at": "2025-10-15T10:00:00Z"
    }
    // ... more assignments
  ],
  "summary": {
    "total_assignments": 15,
    "late_assignments": 8,
    "completed_this_week": 3
  }
}
```

**Enhancement:** Not available in BeProduct (new capability!)

---

### 9. Get Critical Path

**Endpoint:** `GET /api/v1/tracking/plans/{plan_id}/critical-path`

**Description:** Calculate critical path for plan (longest dependency chain)

**Path Parameters:**
- `plan_id` (UUID, required): Plan identifier

**Query Parameters:**
- `entity_type` (string, optional): Filter by entity type

**Response:** `200 OK`
```json
{
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "critical_path": [
    {
      "node_id": "node-uuid-1",
      "milestone_name": "START DATE",
      "due_date": "2025-05-01",
      "path_position": 0
    },
    {
      "node_id": "node-uuid-2",
      "milestone_name": "TECHPACKS PASS OFF",
      "due_date": "2025-05-01",
      "path_position": 1
    },
    {
      "node_id": "node-uuid-3",
      "milestone_name": "PROTO PRODUCTION",
      "due_date": "2025-05-05",
      "path_position": 2
    }
    // ... more milestones in critical path
  ],
  "total_duration_days": 249,
  "path_length": 25
}
```

**Enhancement:** Not available in BeProduct (new capability for Gantt charts!)

---

### 10. Get Timeline Dependencies

**Endpoint:** `GET /api/v1/tracking/timeline/node/{node_id}/dependencies`

**Description:** Get all dependencies for a specific milestone (predecessors and dependents)

**Path Parameters:**
- `node_id` (UUID, required): Timeline node identifier

**Response:** `200 OK`
```json
{
  "node_id": "node-uuid",
  "milestone_name": "PROTO PRODUCTION",
  "predecessors": [
    {
      "predecessor_node_id": "node-uuid-1",
      "predecessor_milestone": "TECHPACKS PASS OFF",
      "dependency_type": "finish_to_start",
      "lag_days": 4
    }
  ],
  "dependents": [
    {
      "dependent_node_id": "node-uuid-3",
      "dependent_milestone": "PROTO EX-FCTY",
      "dependency_type": "finish_to_start",
      "lag_days": 14
    },
    {
      "dependent_node_id": "node-uuid-4",
      "dependent_milestone": "PROTO COSTING DUE",
      "dependency_type": "finish_to_start",
      "lag_days": 16
    }
  ]
}
```

---

### 11. Search Plans

**Endpoint:** `GET /api/v1/tracking/plans`

**Description:** Search and list tracking plans

**Query Parameters:**
- `search` (string, optional): Search term for plan name
- `folder_id` (UUID, optional): Filter by folder
- `status` (string, optional): Filter by plan status [`active`, `archived`]
- `page` (integer, default: `1`): Page number
- `page_size` (integer, default: `20`): Items per page

**Response:** `200 OK`
```json
{
  "plans": [
    {
      "id": "plan-uuid",
      "name": "GREYSON 2026 SPRING DROP 1",
      "start_date": "2025-05-01",
      "end_date": "2026-01-05",
      "folder_id": "folder-uuid",
      "folder_name": "GREYSON 2026",
      "total_milestones": 125,
      "completed_milestones": 5,
      "late_milestones": 110,
      "completion_percentage": 4.0
    }
    // ... more plans
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_items": 11,
    "total_pages": 1
  }
}
```

**Equivalent BeProduct:** `planSearch`

---

### 12. Get Plan Details

**Endpoint:** `GET /api/v1/tracking/plans/{plan_id}`

**Description:** Get plan metadata and template configuration

**Path Parameters:**
- `plan_id` (UUID, required): Plan identifier

**Response:** `200 OK`
```json
{
  "id": "plan-uuid",
  "name": "GREYSON 2026 SPRING DROP 1",
  "start_date": "2025-05-01",
  "end_date": "2026-01-05",
  "folder_id": "folder-uuid",
  "folder_name": "GREYSON 2026",
  "template_id": "template-uuid",
  "template_name": "Garment Production Timeline",
  "style_timeline_template": [
    {
      "id": "milestone-uuid-1",
      "name": "TECHPACKS PASS OFF",
      "phase": "DEVELOPMENT",
      "department": "DESIGN",
      "order": 1,
      "customer_visible": true,
      "supplier_visible": false
    }
    // ... 24 more style milestones
  ],
  "material_timeline_template": [
    {
      "id": "milestone-uuid-26",
      "name": "MATERIAL SUBMITTED",
      "phase": "DEVELOPMENT",
      "department": "PRODUCT DEVELOPMENT",
      "order": 1
    }
    // ... 8 more material milestones
  ],
  "created_at": "2025-04-15T10:00:00Z",
  "updated_at": "2025-10-31T15:30:00Z"
}
```

**Equivalent BeProduct:** `planGet`

---

## HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| `200 OK` | Success | GET, PATCH requests successful |
| `201 Created` | Resource created | POST requests successful |
| `204 No Content` | Success with no body | DELETE requests successful |
| `400 Bad Request` | Invalid input | Validation errors, malformed JSON |
| `401 Unauthorized` | Authentication required | Missing or invalid auth token |
| `403 Forbidden` | Access denied | User lacks permission |
| `404 Not Found` | Resource not found | Invalid ID |
| `409 Conflict` | Concurrent update | Optimistic locking conflict |
| `422 Unprocessable Entity` | Business logic error | Invalid state transition |
| `429 Too Many Requests` | Rate limit exceeded | Throttling |
| `500 Internal Server Error` | Server error | Unexpected failures |

---

## Authentication & Authorization

All endpoints require authentication via JWT bearer token:

```
Authorization: Bearer <jwt_token>
```

**Row-Level Security (RLS):**
- Users can only access timelines for entities they have permission to view
- Assignment/sharing operations check user permissions
- Plan-level access controls inherited by timeline milestones

---

## Rate Limiting

- **Standard endpoints:** 100 requests/minute per user
- **Bulk operations:** 10 requests/minute per user
- **Search endpoints:** 30 requests/minute per user

**Response headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1698765432
```

---

## Versioning

**Current Version:** `v1`  
**Base URL:** `https://api.yourcompany.com/api/v1`

Breaking changes will be introduced in new API versions (`v2`, `v3`, etc.)  
Non-breaking changes (new fields, new optional parameters) will be added to existing versions

---

**Document Status:** ✅ Ready for Implementation  
**Last Updated:** October 31, 2025  
**Version:** 1.0
