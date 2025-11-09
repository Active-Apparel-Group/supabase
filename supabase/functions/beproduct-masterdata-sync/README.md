# BeProduct Masterdata Sync

This Supabase Edge Function synchronizes dropdown/masterdata values from BeProduct into the unified `config.app_config` table.

## Purpose

- Fetches all dropdown field values from BeProduct's masterdata API
- Upserts values into the `config.app_config` table with appropriate category mapping
- Runs on-demand or via scheduled cron job

## Environment Variables

Required in your Supabase project (set via Supabase Dashboard → Project Settings → Edge Functions → Secrets):

- `SUPABASE_URL` - Your Supabase project URL (automatically provided)
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for upsert operations (automatically provided)
- `BEPRODUCT_CLIENT_ID` - BeProduct OAuth client ID
- `BEPRODUCT_CLIENT_SECRET` - BeProduct OAuth client secret
- `BEPRODUCT_REFRESH_TOKEN` - (Optional) BeProduct refresh token for token refresh grant
- `BEPRODUCT_BASE_URL` - (Optional) BeProduct API base URL (defaults to https://developers.beproduct.com)
- `BEPRODUCT_COMPANY` - BeProduct company/tenant identifier

### Setting Secrets via CLI

```bash
supabase secrets set BEPRODUCT_CLIENT_ID=your_client_id
supabase secrets set BEPRODUCT_CLIENT_SECRET=your_client_secret
supabase secrets set BEPRODUCT_REFRESH_TOKEN=your_refresh_token
supabase secrets set BEPRODUCT_COMPANY=your_company
supabase secrets set BEPRODUCT_BASE_URL=https://developers.beproduct.com
```

After setting secrets, redeploy the function:
```bash
supabase functions deploy beproduct-masterdata-sync
```

## Synced Fields

The function syncs the following dropdown fields into `config.app_config`:

- `product_type` → category: `product_type`
- `delivery` → category: `delivery`
- `gender` → category: `gender`
- `product_category` → category: `product_category`
- `year` → category: `year`
- `season` → category: `season`
- `fabric_group` → category: `fabric_group`
- `classification` → category: `classification`
- `status` → category: `status`
- `account_manager` → category: `account_manager`
- `senior_product_developer` → category: `senior_product_developer`
- `color_number_ls` → category: `color_number_ls`

All values are stored with `config_type='enum'` and `data_type='text'`.

## Response Format

```json
{
  "status": "completed",
  "timestamp": "2025-11-03T10:30:00.000Z",
  "results": {
    "product_type": {
      "synced": 45,
      "errors": []
    },
    "delivery": {
      "synced": 12,
      "errors": []
    }
  }
}
```

## Testing

```bash
# Deploy the function
supabase functions deploy beproduct-masterdata-sync

# Invoke manually
supabase functions invoke beproduct-masterdata-sync

# Or via HTTP
curl -X POST https://your-project.supabase.co/functions/v1/beproduct-masterdata-sync \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Scheduling

To run hourly, add to your project's cron configuration:

```sql
-- In Supabase dashboard or via migration
SELECT cron.schedule(
  'sync-beproduct-masterdata',
  '0 * * * *', -- Every hour
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/beproduct-masterdata-sync',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
  );
  $$
);
```

## Error Handling

- Authentication failures are logged and return HTTP 500
- Per-field errors are captured in the results object
- Individual choice upsert errors are logged but don't stop the sync
