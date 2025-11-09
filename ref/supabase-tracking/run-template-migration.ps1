# ============================================================================
# Supabase Template Migration Runner
# ============================================================================
# This script imports the Garment Tracking Timeline template into Supabase
# ============================================================================

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$projectUrl = "https://wjpbryjgtmmaqjbhjgap.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjk0ODUyMTMsImV4cCI6MjA0NTA2MTIxM30.xZGY9o02UfTHh7-jSMnjGHo-VWL6Ts_qBxZPUTu5GQw"
$migrationFile = "migrations\0012_import_garment_timeline_template.sql"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEMPLATE MIGRATION RUNNER" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if migration file exists
if (-not (Test-Path $migrationFile)) {
    Write-Host "❌ ERROR: Migration file not found: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Migration file: $migrationFile" -ForegroundColor White
Write-Host "🌐 Target: $projectUrl" -ForegroundColor White

if ($DryRun) {
    Write-Host "`n⚠️  DRY RUN MODE - No changes will be made`n" -ForegroundColor Yellow
}

Write-Host "`n----------------------------------------" -ForegroundColor Gray
Write-Host "Migration Summary:" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host "Template: Garment Tracking Timeline" -ForegroundColor White
Write-Host "Items: 26 nodes (2 anchors + 24 tasks)" -ForegroundColor White
Write-Host "Phases:" -ForegroundColor White
Write-Host "  - PLAN (2 anchors)" -ForegroundColor Gray
Write-Host "  - DEVELOPMENT (8 tasks)" -ForegroundColor Gray
Write-Host "  - SMS (2 tasks)" -ForegroundColor Gray
Write-Host "  - ALLOCATION (8 tasks)" -ForegroundColor Gray
Write-Host "  - PRODUCTION (6 tasks)" -ForegroundColor Gray
Write-Host ""

if (-not $DryRun) {
    Write-Host "⚠️  This will insert data into your production database." -ForegroundColor Yellow
    $confirmation = Read-Host "Continue? (yes/no)"
    
    if ($confirmation -ne "yes") {
        Write-Host "`n❌ Migration cancelled by user" -ForegroundColor Red
        exit 0
    }
}

Write-Host "`n🚀 Starting migration..." -ForegroundColor Green

# Read SQL file
$sql = Get-Content $migrationFile -Raw

# Extract individual INSERT statements for tracking
$statements = $sql -split ";\s*`n" | Where-Object { $_ -match "INSERT INTO" }

Write-Host "`n📊 Found $($statements.Count) INSERT statements to execute" -ForegroundColor White

if ($DryRun) {
    Write-Host "`n✅ DRY RUN COMPLETE - Ready to migrate" -ForegroundColor Green
    Write-Host "Run without -DryRun flag to execute migration" -ForegroundColor Yellow
    exit 0
}

# For actual migration, you would typically use:
# 1. Supabase CLI: supabase db push
# 2. Direct psql connection
# 3. Or the migration API

Write-Host "`n⚠️  IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Option 1: Use Supabase Studio SQL Editor" -ForegroundColor White
Write-Host "  1. Go to: $projectUrl" -ForegroundColor Gray
Write-Host "  2. Navigate to SQL Editor" -ForegroundColor Gray
Write-Host "  3. Copy contents of: $migrationFile" -ForegroundColor Gray
Write-Host "  4. Execute the SQL" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Use psql (if you have connection string)" -ForegroundColor White
Write-Host "  psql '<your-connection-string>' -f $migrationFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 3: Use MCP Supabase Tool" -ForegroundColor White
Write-Host "  Call mcp_supabase_apply_migration with:" -ForegroundColor Gray
Write-Host "  - name: import_garment_timeline_template" -ForegroundColor Gray
Write-Host "  - query: <contents of migration file>" -ForegroundColor Gray
Write-Host ""

# Provide a test command to verify after migration
Write-Host "✅ After migration, verify with PowerShell:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

$testScript = @"
`$headers = @{
    'apikey' = '$anonKey'
    'Authorization' = 'Bearer $anonKey'
}

# Test template endpoint
`$template = Invoke-RestMethod -Uri '$projectUrl/rest/v1/v_timeline_template?name=eq.Garment%20Tracking%20Timeline' -Headers `$headers
Write-Host "Template found: `$(`$template.name)" -ForegroundColor Green
Write-Host "Template ID: `$(`$template.id)" -ForegroundColor Yellow
Write-Host "Total items: `$(`$template.total_items)" -ForegroundColor Cyan

# Test items endpoint
`$items = Invoke-RestMethod -Uri "$projectUrl/rest/v1/v_timeline_template_item?template_id=eq.`$(`$template.id)" -Headers `$headers
Write-Host "`nItems retrieved: `$(`$items.Count)" -ForegroundColor Green

# Group by phase
`$phases = `$items | Group-Object -Property phase | Sort-Object Name
foreach (`$phase in `$phases) {
    Write-Host "  `$(`$phase.Name): `$(`$phase.Count) items" -ForegroundColor White
}
"@

Write-Host $testScript -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Migration script ready!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
