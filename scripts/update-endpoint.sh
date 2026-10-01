#!/usr/bin/env bash
# Point the GitHub Pages front-end at whatever tunnel is running right now.
#
# ngrok's free tier hands out a new hostname on every restart, so the deployed
# page cannot hard-code one. Run this after starting ngrok and it rewrites
# endpoint.json from ngrok's own API, then commits and pushes it.
#
#   ./scripts/update-endpoint.sh
#
# A reserved/static ngrok domain removes the need for this entirely.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

URL="$(curl -s --max-time 10 http://127.0.0.1:4040/api/tunnels \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["tunnels"][0]["public_url"])')"

if [ -z "$URL" ]; then
  echo "No tunnel found. Is ngrok running?" >&2
  exit 1
fi

python3 - "$URL" <<'PY'
import json, pathlib, sys, datetime
url = sys.argv[1]
path = pathlib.Path("endpoint.json")
path.write_text(json.dumps({
    "object": "endpoint",
    "api_base": url,
    "note": "Sigma backend behind the tunnel. Update with scripts/update-endpoint.sh when the tunnel restarts.",
    "updated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("endpoint.json ->", url)
PY

git add endpoint.json index.html
if git diff --cached --quiet; then
  echo "Already up to date."
  exit 0
fi
git -c user.name="TAI Research" -c user.email="TAI-Research@outlook.com" \
  commit -q -m "Point the front-end at ${URL}"
git push origin main
echo "Pushed. GitHub Pages takes about a minute to serve it."
