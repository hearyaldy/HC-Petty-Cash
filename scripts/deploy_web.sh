#!/usr/bin/env bash
# Builds the Flutter web app and deploys to Firebase Hosting.
#
# The public landing page (web/landing.html) is served at the site root
# ("/"), so Flutter's own generated entry point is renamed to app.html and
# reached via the "**" rewrite in firebase.json instead.
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build web --release

mv build/web/index.html build/web/app.html
mv build/web/landing.html build/web/index.html

firebase deploy --only hosting
