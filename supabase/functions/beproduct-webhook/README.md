# BeProduct Webhook Edge Function

## Overview
This Edge Function handles incoming webhooks from BeProduct PIM system to sync product data in real-time to Supabase. When a style is created or modified in BeProduct, this webhook automatically updates the corresponding records in our `pim` schema tables.

## Purpose
- **Real-time Sync**: Automatically sync BeProduct PIM data to Supabase without manual exports
- **Data Integrity**: Maintain a single source of truth by storing raw BeProduct data alongside normalized fields
- **Event Handling**: Process BeProduct's `OnChange`, `OnCopy`, `OnCreate`, and `OnDelete` webhook events
- **Deletion Sync**: Automatically remove colorways and size classes that are deleted in BeProduct

## Database Schema
This function writes to three tables in the `pim` schema:

### 1. `pim.style`
Main product style information including header details, classifications, and custom fields.

### 2. `pim.style_colorway`
Color variations for each style, including color codes, names, and colorway-specific fields.

### 3. `pim.style_size_class`
Size class definitions and size ranges for each style.

## Webhook Flow

### 1. **Event Reception**
- Receives POST request from BeProduct webhook
- Validates payload structure
- Extracts event type (`OnChange` or `OnCopy`)

### 2. **Style Processing**
- Extracts style data from `payload.after` object
- Maps BeProduct fields to database columns
- Upserts style record using `beproduct_style_id` as conflict key
- Stores complete raw payload in `raw_beproduct_data` jsonb column

### 3. **Colorway Processing**
- Iterates through `after.colorways` array
- Extracts colorway data and nested custom fields
- Links to parent style via `style_id` foreign key
- Upserts each colorway using `beproduct_colorway_id` + `style_id` composite key

### 4. **Size Class Processing**
- Iterates through `after.sizeClasses` array
- Extracts size class metadata and size ranges
- Links to parent style via `style_id` foreign key
- Upserts each size class using `style_id` + `size_class_name` composite key

### 5. **Deletion Sync**
- **OnDelete Event**: Soft-deletes the style (sets `is_deleted = true`)
- **Orphaned Colorways**: Deletes colorways that exist in database but not in incoming payload
- **Orphaned Size Classes**: Deletes size classes that exist in database but not in incoming payload
- Ensures database stays in sync with BeProduct's current state

## Key Features

### Upsert Strategy
All database operations use `upsert` to handle both new records and updates:
```typescript
.upsert(data, { onConflict: "unique_key" })
```

### Raw Data Preservation
Each record stores the complete BeProduct object in a `raw_beproduct_data` jsonb column for:
- Audit trails
- Future field mapping
- Debugging
- Access to unmapped fields

### Error Handling
- Validates required fields (`header_number`, `header_name`)
- Logs detailed error messages for debugging
- Returns appropriate HTTP status codes
- Gracefully handles missing optional data

### Schema Access
Uses explicit schema specification for PostgreSQL access:
```typescript
supabase.schema("pim").from("table_name")
```

## Configuration

### Environment Variables
Required secrets (configured via `supabase secrets set`):
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key with full database access
- `BEPRODUCT_WEBHOOK_SECRET`: (Optional) For webhook signature verification

### JWT Verification
This function has JWT verification **disabled** to allow external webhook access:
```bash
supabase functions deploy beproduct-webhook --no-verify-jwt
```

### Schema Permissions
Service role requires explicit permissions on the `pim` schema:
```sql
GRANT USAGE ON SCHEMA pim TO service_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pim TO service_role;
```

## Deployment

### Deploy Command
```bash
supabase functions deploy beproduct-webhook --no-verify-jwt
```

### Project Structure
```
supabase/functions/beproduct-webhook/
├── index.ts          # Main function handler
└── README.md         # This documentation
```

## Response Formats

### Success Response (200)
```json
{
  "ok": true,
  "styleId": "uuid-of-style",
  "colorwaysCount": 3,
  "sizeClassesCount": 2
}
```

### Error Response (400)
```json
{
  "ok": false,
  "error": "Missing required fields: header_number or header_name"
}
```

### Error Response (500)
```json
{
  "ok": false,
  "error": "Database error message"
}
```

## Monitoring

### Logs
View function logs to monitor webhook execution:
```bash
supabase functions logs beproduct-webhook
```

### Key Metrics
- Execution time: ~2-3 seconds typical
- Status codes: 200 (success), 400 (validation), 500 (server error)
- Events processed: Check `colorwaysCount` and `sizeClassesCount` in response

## BeProduct Integration

### Webhook Configuration
In BeProduct admin:
1. Navigate to Webhooks settings
2. Create new webhook
3. Set URL: `https://[project-ref].supabase.co/functions/v1/beproduct-webhook`
4. Select events: `OnChange`, `OnCopy`, `OnCreate`, `OnDelete`
5. Set content type: `application/json`

### Event Types
- **OnChange**: Triggered when a style is created or modified (syncs updates + removes orphaned child records)
- **OnCopy**: Triggered when a style is duplicated (creates new records)
- **OnCreate**: Triggered when a new style is created
- **OnDelete**: Triggered when a style is deleted (soft-deletes style by setting `is_deleted = true`)

## Data Mapping

### Custom Fields
BeProduct custom fields are accessed via the `fields` property:
```typescript
getField(after, "field_name") // Helper function extracts from fields object
```

### Nested Data
- Colorway fields: `colorway.fields.field_name`
- Size class fields: `sizeClass.fields.field_name`
- User data: `after.createdBy.name`, `after.modifiedBy.name`
- Image data: `after.frontImage.preview`, `after.frontImage.origin`

## Troubleshooting

### Common Issues

**401 Unauthorized**
- JWT verification is enabled (redeploy with `--no-verify-jwt`)

**403 Forbidden / 42501 Permission Denied**
- Service role lacks schema permissions (run migration to grant access)

**PGRST205 Table Not Found**
- Incorrect schema reference (use `schema("pim").from("table")`)

**400 Missing Required Fields**
- BeProduct payload missing `header_number` or `header_name`

**500 Database Error**
- Check data types match schema (uuid, jsonb, etc.)
- Verify foreign key relationships exist
- Check for NULL constraint violations

## Future Enhancements
- [ ] Webhook signature verification using `BEPRODUCT_WEBHOOK_SECRET`
- [ ] Batch processing for bulk updates
- [ ] Webhook retry mechanism with exponential backoff
- [ ] Detailed audit logging table
- [ ] Hard delete option (controlled by environment variable)

## Related Documentation
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [BeProduct API Documentation](https://beproduct.com/docs/api)
- [Database Schema](../../../docs/database-schema-overview.md)
