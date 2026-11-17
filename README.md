# norte_staff

Staff commands for FiveM servers running the **WHIP** framework (WHIPFX). Made by the Norte Roleplay team.

Every command goes through WHIP's own gate (`Whip.command` with `dev = true`). A player needs the `whip.devtools` ACE **and** developer mode turned on in `/w`. Turning developer mode off also turns off noclip, god and invisible.

## Commands

| Command | What it does |
|---|---|
| `/noclip` | Free flight (WASD, Space up, Ctrl down, Shift fast, Alt slow). If you are driving, the car flies with you |
| `/god` | No damage |
| `/invis` | Invisible to other players |
| `/car <model>` | Temporary car with key, you are seated at the wheel. A new `/car` removes the previous one |
| `/dv` | Removes the car you are in, or the nearest one. An owned car goes back to its garage |
| `/fix` | Repairs the car you are in |
| `/revive [id]` | Revives a player (no id: yourself) |
| `/heal [id]` | Health, armour, hunger and thirst to full |
| `/tp <id>` | Teleports you to a player |
| `/bring <id>` | Brings a player to you |
| `/tpm` | Teleports you to the map waypoint |
| `/tpc <x> <y> <z>` | Teleports you to coordinates |
| `/voltar` | Goes back to where you were before the last teleport |
| `/freeze <id>` | Freezes or unfreezes a player |
| `/kick <id> [reason]` | Kicks a player |
| `/hora <h> [m]` | Sets the server time |
| `/clima <type>` | Sets the weather (CLEAR, RAIN, THUNDER...) |
| `/anuncio <text>` | Announcement to every player |

`revive`, `heal`, `kick`, `freeze`, `hora`, `clima` and `anuncio` also run from the server console. Every use is printed to the server console. The full list with examples is in `COMMANDS_EN.txt`.

## Requirements

- WHIP (`whip_core` 1.0 or newer). No other dependency: no ox_lib, no database.

## Install

1. Put the `norte_staff` folder in your `resources`.
2. Add `ensure norte_staff` to your `server.cfg`, after `whip_core`.
3. Give your staff the ACE: `add_ace group.admin whip.devtools allow`.

## Settings

Noclip speeds, the `/dv` radius, how long a `/car` lasts and the `/anuncio` length are in `config.lua`. They can also be changed in game at `/whip` → Settings → Norte Staff, and changes apply at once.

## Notes

- In-game messages and some command names (`/voltar`, `/hora`, `/clima`, `/anuncio`) are in Portuguese. Rename them in `server.lua` if you want.
- God, invisible, noclip and freeze use WHIP's `HoldPlayerPed`, so they combine with other resources without fighting over the ped.

## License

MIT. See `LICENSE`.
