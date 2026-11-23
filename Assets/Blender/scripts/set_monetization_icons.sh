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
pass 2093460329 Icon_Star

product 3734667473 Icon_Meteor
product 3734667479 Icon_Potion
product 3734667487 Icon_Potion
product 3734667495 Velociraptor
product 3734667504 Icon_Cash
product 3734667512 Icon_Cash
product 3734667525 Icon_Vault
product 3734667534 Icon_Gift
# One icon per slingshot tier (Bamboo .. Meteorite).
product 3734667545 Icon_Sling_Bamboo
product 3734667556 Icon_Sling_Bone
product 3734667565 Icon_Sling_TarRubber
product 3734667575 Icon_Sling_MammothTusk
product 3734667581 Icon_Sling_Obsidian
product 3734667589 Icon_Sling_Meteorite
# Luck potions and pass gifts.
product 3734723453 Icon_Potion
product 3734723473 Icon_Potion
product 3734731964 Icon_DoubleCash
product 3734731982 Icon_DoublePower
product 3734732000 Icon_Star
product 3734732013 Icon_Gear
product 3734732025 Icon_Crown
product 3734667597 Bait_Fish
product 3734667604 Bait_Steak
product 3734667613 Bait_GoldenEgg
product 3734667622 Bait_AmberMosquito
product 3734667631 Bait_MeteorMeat
# Robux pets (golden / cosmic tints of the plush portraits).
product 3735175296 Pet_GoldenRex
product 3735175313 Pet_CosmicPtero
# Speed Boots pass and its gift product.
pass 2093749386 Icon_Speed
product 3735272732 Icon_Speed
