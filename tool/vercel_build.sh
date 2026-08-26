#!/usr/bin/env bash
# Vercel build entry point for Glow Up's Flutter Web deployment.
#
# Root cause this exists to fix: the repo had no vercel.json/package.json/
# build script at all, so Vercel had nothing telling it this is a Flutter
# project and nothing to serve at the root — hence the "404: NOT_FOUND".
# This script is that missing build step; vercel.json's buildCommand
# invokes it, and outputDirectory points at build/web (only produced here).
#
# Vercel's build environment is Linux — never assume a Windows path or the
# local dev machine's checkout location (C:\Projects\glow_up). Everything
# below is relative to the repo root Vercel checks out.
set -euo pipefail

# Flutter's first run otherwise shows an interactive analytics consent
# prompt, which would hang a non-interactive CI build forever. CI=true is
# Flutter's own documented way to skip it.
export CI=true

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found on PATH — installing the stable channel..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter config --enable-web --no-analytics
flutter pub get

# Only the two public dart-defines Glow Up's Web build actually reads
# (audited directly from lib/auth/config/auth_config.dart,
# lib/coach/config/coach_backend_config.dart, and
# lib/scan/config/scan_backend_config.dart — every one of them reads
# exactly SUPABASE_URL/SUPABASE_ANON_KEY via String.fromEnvironment, never
# a different name). Both must be set as real Vercel project environment
# variables (Project Settings -> Environment Variables) — SUPABASE_URL and
# the public anon/publishable key ONLY. Never the service-role key or any
# other provider secret; none of those are ever read by client Dart code.
#
# WEB_PROD_REDIRECT_URI is not a secret — it's simply this deployment's own
# known public URL, already wired through AuthConfig.webRedirectUri (see
# lib/auth/config/auth_config.dart) so Google/email OAuth redirects back to
# the real production origin instead of the http://localhost:3000 dev
# fallback. Hardcoded here (not a Vercel env var) because it is a fixed,
# public, non-sensitive constant for this exact deployment.
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL Vercel environment variable is not set}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY Vercel environment variable is not set}" \
  --dart-define=WEB_PROD_REDIRECT_URI="https://glowup-flutter.vercel.app/auth-callback"
