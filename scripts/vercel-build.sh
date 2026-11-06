#!/usr/bin/env bash
# Vercel build step: compile the Flutter web admin panel.
# Set SUPABASE_URL and SUPABASE_ANON_KEY in the Vercel project's Environment Variables.
set -euo pipefail
: "${SUPABASE_URL:?Set SUPABASE_URL in Vercel → Project → Settings → Environment Variables}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY in Vercel → Project → Settings → Environment Variables}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
cd app
"$FLUTTER_DIR/bin/flutter" build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
