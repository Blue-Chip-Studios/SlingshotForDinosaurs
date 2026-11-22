#!/usr/bin/env bash
# Creates the launch analytics alerts through the Open Cloud Analytics Alerts API.
# Safe to re-run: alerts that already exist (same name) are reported and skipped.
# Needs the API key permission universe-analytics > universe.analytics.alert:write (+ :read).
# Alerts show in Creator Dashboard > Analytics > Alerts; add a webhook there to get pinged.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
UNIVERSE=10778444607
KEY=$(grep -E '^\s*ROBLOX_API_KEY\s*=' .env | head -1 | sed -E 's/^\s*ROBLOX_API_KEY\s*=\s*//; s/\r$//; s/^"//; s/"$//')
URL="https://apis.roblox.com/analytics-alert-control-plane/v1/resource/Universe/id/$UNIVERSE/alerts"

create() {
  local NAME="$1" BODY="$2"
  local RESP CODE
  RESP=$(curl -s -w '\n%{http_code}' -X POST "$URL" -H "x-api-key: $KEY" -H "Content-Type: application/json" --data "$BODY")
  CODE=$(echo "$RESP" | tail -1)
  case "$CODE" in
    201) echo "OK      $NAME" ;;
    409) echo "EXISTS  $NAME" ;;
    *)   echo "FAILED  $NAME ($CODE) $(echo "$RESP" | sed '$d')" ;;
  esac
}

# Launch-critical: something is broken right now.
create "Client crash rate high" '{"name":"Client crash rate high","description":"Client crash rate above 3% for 15 minutes","metric":"ClientCrashRate15m","severity":"SEV_0","interval":"OneMinute","consecutiveOccurrences":15,"condition":{"operator":"Gt","threshold":3,"evaluationMode":"Absolute"}}'
create "Server FPS low" '{"name":"Server FPS low","description":"Average server frame rate below 40 for 10 minutes","metric":"ServerFrameRateAvg","severity":"SEV_0","interval":"OneMinute","consecutiveOccurrences":10,"condition":{"operator":"Lt","threshold":40,"evaluationMode":"Absolute"}}'
create "Phone FPS low" '{"name":"Phone FPS low","description":"Average phone client FPS below 30 for 2 hours","metric":"ClientFpsAvg","severity":"SEV_1","interval":"OneHour","consecutiveOccurrences":2,"filter":[{"dimension":"Platform","values":["Phone"]}],"condition":{"operator":"Lt","threshold":30,"evaluationMode":"Absolute"}}'

# Trend drops: compare with the same day last week.
create "Players down week over week" '{"name":"Players down week over week","description":"Daily active users down 30% vs the same day last week","metric":"DailyActiveUsers","severity":"SEV_1","interval":"OneDay","consecutiveOccurrences":1,"condition":{"operator":"Lt","threshold":-30,"evaluationMode":"PeriodOverPeriod","periodOffsetMultiplier":7}}'
create "Peak CCU down week over week" '{"name":"Peak CCU down week over week","description":"Peak concurrent players down 30% vs the same day last week","metric":"PeakConcurrentPlayers","severity":"SEV_1","interval":"OneDay","consecutiveOccurrences":1,"condition":{"operator":"Lt","threshold":-30,"evaluationMode":"PeriodOverPeriod","periodOffsetMultiplier":7}}'
create "Revenue down week over week" '{"name":"Revenue down week over week","description":"Daily revenue down 40% vs the same day last week (broken purchases?)","metric":"DailyRevenue","severity":"SEV_1","interval":"OneDay","consecutiveOccurrences":1,"condition":{"operator":"Lt","threshold":-40,"evaluationMode":"PeriodOverPeriod","periodOffsetMultiplier":7}}'
create "D1 retention down" '{"name":"D1 retention down","description":"Day 1 retention down 25% vs a week earlier","metric":"ForwardD1Retention","severity":"SEV_2","interval":"OneDay","consecutiveOccurrences":2,"condition":{"operator":"Lt","threshold":-25,"evaluationMode":"PeriodOverPeriod","periodOffsetMultiplier":7}}'
