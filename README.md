# n4k_blipcreator

Create, edit, move, disable and delete map blips from inside the game. Changes are saved on the
server and synced live to every player. Built on ox_lib; works with **ESX**, **QBCore** and **Qbox**.

## Features

- Context-menu manager: create at your position, list with pages, search by name or ID.
- Official blip sprite and colour catalog with search.
- 15-second local preview before saving.
- Server-side validation, permission check on every request, anti-spam cooldown.
- Revision control: if another admin changed the list, your edit is rejected instead of overwriting it.
- Atomic save with automatic backup (`data/blips.backup.json`).
- Translatable through `locales/*.json` (Italian and English included).

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- One supported framework: `es_extended`, `qb-core` or `qbx_core`

## Installation

1. Put the `n4k_blipcreator` folder in your `resources` directory.
2. In `server.cfg`, after `ox_lib` and your framework:

   ```
   ensure n4k_blipcreator
   ```

3. Open `config.lua` and check `Config.Framework` and `Config.Permissions`.
4. Restart the server and use `/blipcreator` in game.

The events and callbacks are named after the resource, so keep the folder name `n4k_blipcreator`.

## Configuration

| Option | Description |
| --- | --- |
| `Config.Command` | Command that opens the manager. |
| `Config.Locale` | `'auto'` (follows `setr ox:locale xx`) or a file name in `locales/`. |
| `Config.Framework` | `'auto'`, `'esx'`, `'qbcore'` or `'qbox'`. |
| `Config.FrameworkResources` | Resource name of each framework, if you renamed them. |
| `Config.Permissions` | Groups (ESX/QBCore) or ACE objects (Qbox) allowed to manage blips. |
| `Config.MaxBlips` | Maximum number of blips. |
| `Config.MutationCooldown` | Minimum milliseconds between two saves from the same player. |
| `Config.PageSize` | Blips shown per page. |
| `Config.Default` | Default values of the create form. |

## Languages

Texts live in `locales/<code>.json`. `en` is always the fallback. To add a language, copy
`locales/en.json` to `locales/xx.json`, translate the values (keep the keys and the `%s`/`%d`
placeholders) and set `Config.Locale = 'xx'`, or `setr ox:locale xx` with `Config.Locale = 'auto'`.

## Data

Blips are stored in `data/blips.json`. Before every save the previous state is written to
`data/blips.backup.json`. If the archive is missing or invalid the resource refuses to start
instead of overwriting it: restore the file from the backup and restart.

## Troubleshooting

- **"No framework started"** in the console: start your framework before `n4k_blipcreator`, or
  set `Config.Framework` and `Config.FrameworkResources` explicitly.
- **"You don't have permission"**: your group is not listed in `Config.Permissions` for your framework.
- **Texts show raw keys**: the locale file is missing or has a JSON syntax error.

## License

Released under the [MIT License](LICENSE.md). Copyright (c) 2026 N4K LABS.

You may use, modify and redistribute this resource, including commercially, as long as the
copyright notice and license text are kept. ox_lib is a separate project under its own license.
