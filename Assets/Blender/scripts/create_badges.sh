#!/usr/bin/env bash
# Creates the badges in Config/BadgeConfig.luau that still have Id = 0, via Open Cloud
# (legacy-badges). Sends expectedCost=0, so Roblox refuses instead of charging once the
# free daily quota is used up: run it again the next day for the rest.
# Prints "Key BadgeId" lines to paste into BadgeConfig. Never prints the API key.
# Needs the API key permission: legacy-badges (badge create/manage) for this universe.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
UNIVERSE=10778444607
KEY=$(grep -E '^\s*ROBLOX_API_KEY\s*=' .env | head -1 | sed -E 's/^\s*ROBLOX_API_KEY\s*=\s*//; s/\r$//; s/^"//; s/"$//')

# Key|Name|Description|Icon for every badge whose Id is 0.
grep -E '^\s+[A-Za-z_]+ = \{ Id = 0,' Config/BadgeConfig.luau | \
  sed -E 's/^\s+([A-Za-z_]+) = \{ Id = 0, Name = "([^"]*)", Description = "([^"]*)", Icon = "([^"]*)".*/\1|\2|\3|\4/' | \
while IFS='|' read -r BKEY BNAME BDESC BICON; do
  ICON="Assets/Exports/Icons/$BICON.png"
  RESP=$(curl -s -w '\n%{http_code}' -X POST "https://apis.roblox.com/legacy-badges/v1/universes/$UNIVERSE/badges" \
    -H "x-api-key: $KEY" \
    --form-string "name=$BNAME" --form-string "description=$BDESC" \
    --form-string "paymentSourceType=2" --form-string "expectedCost=0" --form-string "isActive=true" \
    -F "files=@$ICON;type=image/png")
  CODE=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | sed '$d')
  ID=$(echo "$BODY" | sed -nE 's/.*"id":([0-9]+).*/\1/p')
  if [ "$CODE" = "200" ] && [ -n "$ID" ]; then
    echo "$BKEY $ID"
  else
    echo "$BKEY FAILED ($CODE) $BODY"
    echo "$BODY" | grep -qi "funds\|cost" && { echo "Free quota used up for today; run again tomorrow."; exit 0; }
  fi
  sleep 1
done
