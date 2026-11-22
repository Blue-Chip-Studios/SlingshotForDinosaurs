# SlingshotForDinosaurs

Roblox experience built with [Rojo](https://github.com/rojo-rbx/rojo) 7.5.1, [Wally](https://github.com/UpliftGames/wally) for packages and [Aftman](https://github.com/LPGhatguy/aftman) for the toolchain. Uses the [BCDK](https://github.com/Blue-Chip-Studios/BCDK) framework as a git submodule.

## Getting Started

```bash
git submodule update --init --recursive
aftman install
wally install
rojo build -o "SlingshotForDinosaurs.rbxlx"
```

Open `SlingshotForDinosaurs.rbxlx` in Roblox Studio, then start the Rojo server (port 52063):

```bash
rojo serve
```

Secrets such as API keys go in `.env`, which is gitignored. After cloning, copy `.env.example` to `.env` and fill in the values; when you add a key, add it (without its value) to `.env.example` too.

## Layout

| Folder | DataModel location |
| --- | --- |
| `Scripts/Server` | `ServerScriptService.ServerScripts` |
| `Scripts/Client` | `StarterPlayer.StarterPlayerScripts.ClientScripts` |
| `Scripts/Character` | `StarterPlayer.StarterCharacterScripts.CharacterScripts` |
| `Scripts/First` | `ReplicatedFirst` |
| `Modules/Server` | `ServerStorage.ServerModules` |
| `Modules/Client` | `ReplicatedStorage.ClientModules` |
| `Modules/Shared` | `ReplicatedStorage.Shared` |
| `Gui` | `ReplicatedStorage.Gui` (Fusion UI modules) |
| `Config` | `ReplicatedStorage.Config` |
| `Packages` | `ReplicatedStorage.Packages` (Wally, gitignored) |
| `BCDK` | `BCDKClient` / `BCDKServer` / `BCDKShared` + `External` (Replica, ProfileStore) |

`initServer` / `initClient` load every module in `ServerModules` / `ClientModules` through the BCDK `Loader`, calling `PreloadAsync` then `StartAsync` (plus the lobby/game variants chosen by `Shared.PlaceManager`).

## Enabling more BCDK modules

The project starts with `SMProfile` (server) and `LMGui` (client). To use another kit module, map it in `default.project.json` under `ServerStorage.BCDKServer` / `ReplicatedStorage.BCDKClient` and add the config it requires:

| Module | Needs |
| --- | --- |
| `SMCurrency` / `LMCurrency` | `Config/CurrencyConfig.luau` |
| `SMXP` / `LMXP` | `Config/XPConfig.luau` |
| `SMQuests` / `LMQuests` | `Config/QuestConfig.luau`, `CurrencyConfig`, `SMXP`, `SMCurrency` |
| `SMInventory` / `LMInventory` | `Config/InventoryConfig.luau`, `CurrencyConfig`, `SMCurrency` |
