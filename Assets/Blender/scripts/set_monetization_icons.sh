#!/usr/bin/env bash
# Sets Blender-rendered icons on the game's passes and developer products (Open Cloud PATCH).
# Reads ROBLOX_API_KEY from .env internally; never prints it.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
KEY=$(grep -E '^\s*ROBLOX_API_KEY\s*=' "$ROOT/.env" | head -1 | sed -E 's/^\s*ROBLOX_API_KEY\s*=\s*//; s/\r$//; s/^"//; s/"$//')
U=10778444607
cd "$ROOT"
I="Assets/Exports/Icons"

pass() { # id icon
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -H "x-api-key: $KEY" "https://apis.roblox.com/game-passes/v1/universes/$U/game-passes/$1" -F "imageFile=@$I/$2.png;type=image/png")
  echo "pass $1 $2 -> $code"; sleep 0.3
}
product() { # id icon
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -H "x-api-key: $KEY" "https://apis.roblox.com/developer-products/v2/universes/$U/developer-products/$1" -F "imageFile=@$I/$2.png;type=image/png")
  echo "product $1 $2 -> $code"; sleep 0.3
}

pass 2094102161 Icon_DoubleCash
pass 2096418101 Icon_DoublePower
pass 2092638260 Icon_Gear
pass 2093292202 Icon_Crown

product 3734667473 Icon_Meteor
product 3734667479 Icon_Potion
product 3734667487 Icon_Potion
product 3734667495 Velociraptor
product 3734667504 Icon_Cash
product 3734667512 Icon_Cash
product 3734667525 Icon_Vault
product 3734667534 Icon_Gift
for id in 3734667545 3734667556 3734667565 3734667575 3734667581 3734667589; do product $id SlingshotItem; done
product 3734667597 Bait_Fish
product 3734667604 Bait_Steak
product 3734667613 Bait_GoldenEgg
product 3734667622 Bait_AmberMosquito
product 3734667631 Bait_MeteorMeat
