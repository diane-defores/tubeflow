#!/bin/bash
set -e

flutter/bin/flutter build web \
  --web-renderer html \
  --dart-define=CONVEX_URL=${NEXT_PUBLIC_CONVEX_URL:-$CONVEX_URL} \
  --dart-define=CLERK_PUBLISHABLE_KEY=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY:-$CLERK_PUBLISHABLE_KEY} \
  2>&1 \
|| {
  echo '=== DART ERRORS ==='
  flutter/bin/flutter analyze --no-pub 2>&1 | tail -50
  exit 1
}
