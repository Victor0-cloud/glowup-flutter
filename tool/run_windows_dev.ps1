# Reliable local Windows dev launcher for Glow Up.
#
# Root cause this exists to fix: AuthConfig reads SUPABASE_URL/
# SUPABASE_ANON_KEY purely via String.fromEnvironment, so any launch that
# forgets --dart-define values silently produces a build where
# AuthConfig.isConfigured is false ("Supabase is not configured on this
# build."). Past sessions alternated between defined and undefined plain
# "flutter run -d windows" invocations, so the two builds looked identical
# but behaved differently. This script is the one supported way to launch
# for local development: it reads config/dev.local.json (gitignored, never
# committed) via --dart-define-from-file and REFUSES to launch rather than
# silently starting an unconfigured build.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config\dev.local.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Missing local Supabase config: $configPath. Create it from the tracked example (Copy-Item config\dev.example.json config\dev.local.json) then fill in your real SUPABASE_URL and SUPABASE_ANON_KEY (the public anon key only, never service_role). This file is gitignored and must never be committed."
    exit 1
}

$configJson = Get-Content $configPath -Raw | ConvertFrom-Json

$missing = @()
if ([string]::IsNullOrWhiteSpace($configJson.SUPABASE_URL)) { $missing += "SUPABASE_URL" }
if ([string]::IsNullOrWhiteSpace($configJson.SUPABASE_ANON_KEY)) { $missing += "SUPABASE_ANON_KEY" }

if ($missing.Count -gt 0) {
    Write-Error "config\dev.local.json is missing a value for: $($missing -join ', '). Refusing to launch an unconfigured build - edit that file and try again."
    exit 1
}

# Stop only stale Glow Up windows (exact process name match) - never touches
# any other Flutter app that might be running.
$stale = Get-Process glow_up -ErrorAction SilentlyContinue
if ($stale) {
    Write-Host "Stopping $($stale.Count) stale glow_up.exe instance(s)..."
    $stale | Stop-Process -Force
    Start-Sleep -Milliseconds 500
}

Write-Host "Launching Glow Up (Windows) with config\dev.local.json..."
Set-Location $repoRoot
flutter run -d windows --dart-define-from-file=config/dev.local.json
