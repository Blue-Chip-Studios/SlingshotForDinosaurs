#!/usr/bin/env bash
# Uploads one asset file to Roblox via Open Cloud (Assets API) and prints "NAME ASSET_ID".
# Usage: upload_asset.sh <file> <assetType: Model|Audio|Decal> <displayName> [groupId]
# Reads ROBLOX_API_KEY from the project's .env internally and never prints it.
set -u
FILE="$1"; TYPE="$2"; NAME="$3"; GROUP="${4:-144483796}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
KEY=$(grep -E '^\s*ROBLOX_API_KEY\s*=' "$ROOT/.env" | head -1 | sed -E 's/^\s*ROBLOX_API_KEY\s*=\s*//; s/\r$//; s/^"//; s/"$//')
case "$FILE" in
  *.fbx) CT="model/fbx" ;;
  *.mp3) CT="audio/mpeg" ;;
  *.ogg) CT="audio/ogg" ;;
  *.png) CT="image/png" ;;
  *) CT="application/octet-stream" ;;
esac
REQ=$(printf '{"assetType":"%s","displayName":"%s","description":"SlingshotForDinosaurs asset","creationContext":{"creator":{"groupId":"%s"}}}' "$TYPE" "$NAME" "$GROUP")
RESP=$(curl -s -X POST "https://apis.roblox.com/assets/v1/assets" -H "x-api-key: $KEY" \
  --form-string "request=$REQ" -F "fileContent=@$FILE;type=$CT")
OP=$(echo "$RESP" | sed -nE 's/.*"operationId":"([^"]+)".*/\1/p')
[ -z "$OP" ] && OP=$(echo "$RESP" | sed -nE 's/.*"path":"operations\/([^"]+)".*/\1/p')
if [ -z "$OP" ]; then echo "$NAME ERROR $RESP"; exit 1; fi
for i in $(seq 1 30); do
  sleep 2
  R=$(curl -s "https://apis.roblox.com/assets/v1/operations/$OP" -H "x-api-key: $KEY")
  if echo "$R" | grep -q '"done":true'; then
    ID=$(echo "$R" | sed -nE 's/.*"assetId":"?([0-9]+)"?.*/\1/p')
    if [ -n "$ID" ]; then echo "$NAME $ID"; else echo "$NAME ERROR $R"; fi
    exit 0
  fi
done
echo "$NAME TIMEOUT $OP"
