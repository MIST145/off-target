<div align="center">

# 🎯 off-target

**A right-click context menu for FiveM with drop-in `ox_target` and `qtarget` compatibility layers.**

Hold the menu key, right-click anything in the world, and act on it.

![FiveM](https://img.shields.io/badge/FiveM-resource-orange)
![Lua](https://img.shields.io/badge/Lua-5.4-blue)
![React](https://img.shields.io/badge/UI-React%2018-61dafb)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

## Preview:
https://www.youtube.com/watch?v=peS7m275vEY
<img width="392" height="312" alt="Capture d&#39;écran 2026-06-05 213419" src="https://github.com/user-attachments/assets/1168b28b-161a-4ee2-8aa7-46f654cc7778" />


## Table of contents

- [Features](#features)
- [How it works](#how-it-works)
- [Installation](#installation)
- [Building the UI](#building-the-ui)
- [Configuration](#configuration)
- [ox_target compatibility](#ox_target-compatibility)
- [qtarget compatibility](#qtarget-compatibility)
- [Native API](#native-api)
- [Project structure](#project-structure)
- [Publishing to GitHub](#publishing-to-github)
- [Full documentation](#full-documentation)
- [License](#license)

-

## Features

- 🖱️ **Right-click context menu** with a clean, animated NUI (React + Vite).
- 🔌 **Drop-in `ox_target` replacement** — existing scripts work without code changes.
- 🔁 **`qtarget` compatibility layer** — legacy `exports.qtarget:*` scripts keep working without renaming the resource.
- 🧱 **Builder API** for custom menus (items, checkboxes, submenus, separators, info rows, copy-to-clipboard).
- 🎯 **Screen raycast** resolves the entity / model / coordinates under the cursor.
- 👤 **Player scoping** — target everyone, only yourself, or only other players.
- 📦 **Zones** — sphere, box and polygon, with optional on-screen markers.
- 🎨 Per-item icons (Font Awesome), accent colors, descriptions and paging.

-

## How it works

1. You hold the **menu key** (default `LEFT ALT`) — the NUI cursor appears.
2. You **right-click** in the world.
3. A screen-space raycast finds what is under the cursor (entity, model, world position).
4. Every registered target callback is asked what to show for that hit.
5. Matching options are merged into one menu and rendered.

There are two ways to register targets:

- The **`ox_target` / `qtarget` exports** (for compatibility with the existing ecosystem).
- The **native `ContextMenu` builder** (for full control).

-

## Installation

1. Drop the resource into your `resources` folder.
2. **Build the UI** once (see below) so `web/build` exists.
3. Add to your `server.cfg`:

```cfg
ensure off-target
```

> ⚠️ The manifest declares `provide 'ox_target'` and `provide 'qtarget'`.
> **Do not run the real `ox_target` or `qtarget` at the same time** — they would conflict.

-

## Building the UI

The menu interface lives in `web/` and compiles to `web/build`, which the manifest serves.

```bash
cd web
npm install
npm run build
```

| Command | Description |
| --- | --- |
| `npm run dev` | Browser preview (right-click anywhere to open a demo menu). |
| `npm run build` | Production build into `web/build`. |
| `npm run game` | Rebuild on every change (`vite build --watch`). |
| `npm run lint` | Run ESLint. |

-

## Configuration

Everything lives in [`shared/shared.lua`](shared/shared.lua):

```lua
Config = {}

Config.MenuKey = 'LMENU'                  -- key that opens the menu (FiveM key name)
Config.RaycastDistance = 300.0            -- max world raycast distance
Config.ItemsPerPage = 9                   -- items before paging kicks in
Config.DefaultEntityIcon = 'fa-solid fa-circle'
Config.PlayerInteractDistance = 2.5       -- default player interact distance

Config.MarkerClickRadius = 18             -- click radius (pixels) around a zone marker
Config.MarkerDrawDistance = 7.0           -- max distance a zone marker is drawn
```

| Key | Default | Description |
| --- | --- | --- |
| `MenuKey` | `'LMENU'` | FiveM key name that opens the menu. |
| `RaycastDistance` | `300.0` | Max world raycast distance. |
| `ItemsPerPage` | `9` | Root items shown before paging. |
| `DefaultEntityIcon` | `'fa-solid fa-circle'` | Fallback icon. |
| `PlayerInteractDistance` | `2.5` | Default interact distance on players. |
| `MarkerClickRadius` | `18` | Click radius in pixels around a zone marker. |
| `MarkerDrawDistance` | `7.0` | Max distance a zone marker is drawn. |

Common key names: `LMENU` (Left Alt), `RMENU` (Right Alt), `LCONTROL`, `B`, `F1`…
Players can also rebind it in **Settings → Key Bindings → FiveM**.

-

## ox_target compatibility

> ⚠️ **To use the `ox_target` integration, rename the resource folder to `ox_target`**
> (and remove the real `ox_target`). Exports resolve by resource name, so
> `exports.ox_target:*` only hits this resource if it is named `ox_target`.
> The **qtarget** layer (`exports.qtarget:*`) works without renaming.

Existing scripts keep working unchanged:

```lua
exports.ox_target:addGlobalVehicle({
    {
        name = 'flip',
        label = 'Flip vehicle',
        icon = 'fa-solid fa-rotate',
        distance = 3.0,
        onSelect = function(data)
            SetVehicleOnGroundProperly(data.entity)
        end,
    },
})
```

**Supported exports**

| Category | Exports |
| --- | --- |
| Players | `addGlobalPlayer`, `addGlobalSelfPlayer`, `addGlobalOtherPlayer`, `removeGlobalPlayer`, `removeGlobalSelfPlayer`, `removeGlobalOtherPlayer` |
| Peds | `addGlobalPed`, `removeGlobalPed` |
| Vehicles | `addGlobalVehicle`, `removeGlobalVehicle` |
| Objects | `addGlobalObject`, `removeGlobalObject` |
| Global | `addGlobalOption`, `removeGlobalOption` |
| Models | `addModel`, `removeModel` |
| Networked entities | `addEntity`, `removeEntity` |
| Local entities | `addLocalEntity`, `removeLocalEntity` |
| Zones | `addSphereZone`, `addBoxZone`, `addPolyZone`, `removeZone` |
| Misc | `disableTargeting` |

**Player scoping**

| Export | Shows on |
| --- | --- |
| `addGlobalPlayer` | every player (yourself **and** others) |
| `addGlobalSelfPlayer` | only yourself |
| `addGlobalOtherPlayer` | only other players |

**Option fields**

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Unique id (used by `remove*`). |
| `label` | string | Text shown in the menu. |
| `icon` | string | Font Awesome class. |
| `iconColor` | `{r,g,b}` | Accent color. |
| `distance` | number | Max interact distance (default `7.0`). |
| `canInteract` | function | `(entity, distance, coords, name, bone) → boolean`. |
| `onSelect` | function | `(data)` — primary action. |
| `event` / `serverEvent` | string | Trigger a client / server event with `data`. |
| `command` | string | Execute a console command. |
| `export` | string | `'resource.function'`, called with `data`. |

`data` passed to actions: `{ entity, coords, distance }`.

-

## qtarget compatibility

Legacy `qtarget` scripts work **without renaming the resource** — the layer hooks
the `__cfx_export_qtarget_*` events directly and forwards to `off-target`.

```lua
-- only other players (type routes to the matching scope)
exports.qtarget:Player({
    options = { ... },
    distance = 1.5,
    type = 'other',   -- 'self' = yourself, 'other' = others, nil/omitted = everyone
})
```

| `type` | Routed to |
| --- | --- |
| `'self'` | `addGlobalSelfPlayer` |
| `'other'` | `addGlobalOtherPlayer` |
| omitted / other | `addGlobalPlayer` |

**Supported qtarget exports**

| Category | Exports |
| --- | --- |
| Zones | `AddBoxZone`, `AddPolyZone`, `AddCircleZone`, `RemoveZone` |
| Globals | `Ped`, `Vehicle`, `Object`, `Player`, `Globals` (+ matching `Remove*`) |
| Models | `AddTargetModel`, `RemoveTargetModel` |
| Entities | `AddTargetEntity`, `RemoveTargetEntity` |
| Bones | `AddTargetBone` |

qtarget option fields (`action`, `job`, `item`/`required_item`, `event` + `type`)
are converted automatically to the `off-target` schema.

-

## Native API

Register a builder callback. It runs on every right-click with the raycast result:

```lua
ContextMenu.Register(function(builder, entity, entityType, worldPos, hit)
    if not hit then return end

    builder:SetHeader('Player', 'fa-solid fa-user')

    builder:AddItem(0, 'Greet', function(ent, coords)
        print('greeted', ent)
    end, 'fa-solid fa-hand', { color = { 99, 102, 241 } }, 'Says hello.')

    builder:AddInfo(0, 'Entity', tostring(entity), 'fa-solid fa-hashtag')
    builder:AddSeparator(0)

    builder:AddCheckbox(0, 'Outline', false, function(checked)
        print('outline', checked)
    end, 'fa-solid fa-vector-square')

    local sub = builder:AddSubmenu(0, 'More', 'fa-solid fa-ellipsis')
    builder:AddItem(sub, 'Sub action', function() end, 'fa-solid fa-gear')
end)
```

`entityType`: `0` world · `1` ped · `2` vehicle · `3` object.

See [`exemple.lua`](exemple.lua) for complete, runnable examples and
[`DOCS.md`](DOCS.md) for the full builder reference.

-

## Project structure

```
off-target/
├─ fxmanifest.lua          # Resource manifest (provides 'ox_target' + 'qtarget')
├─ shared/
│  └─ shared.lua           # Config: key, distances, paging, markers
├─ client/
│  ├─ keys.lua             # Keybinding helper
│  ├─ contextmenu.lua      # Menu core: NUI bridge, raycast, builder
│  ├─ ox_target.lua        # ox_target compatibility layer
│  └─ qtarget.lua          # qtarget compatibility layer
├─ exemple.lua             # Usage examples (not loaded by the manifest)
├─ DOCS.md                 # Full documentation
└─ web/                    # React (Vite) NUI
   ├─ src/                 # UI source
   └─ build/               # Compiled UI (served by the manifest)
```

-

## Publishing to GitHub

You can ship **source + compiled UI** so users don't have to build anything.

```bash
cd web && npm install && npm run build && cd ..
git init
git add .
git commit -m "Initial release"
git remote add origin https://github.com/<you>/off-target.git
git push -u origin main
```

What gets committed and what doesn't is handled by `.gitignore`:

| Path | Committed? | Why |
| --- | --- | --- |
| `client/`, `shared/`, `fxmanifest.lua`, `exemple.lua` | ✅ | The resource. |
| `web/src/`, `web/package.json`, configs | ✅ | UI source. |
| **`web/build/`** | ✅ | So the resource runs without building. |
| `web/node_modules/` | ❌ | Reinstalled with `npm install`. |
| `*.tsbuildinfo`, `web/dist/` | ❌ | Build cache. |

> **TL;DR:** build with `npm run build`, then push. `node_modules` is ignored
> automatically, and `web/build` **is** committed so the resource runs out of the box.

If instead you prefer a **source-only** repo (users build themselves), add
`web/build` to `.gitignore` and tell them to run `npm install && npm run build`.

-

## Full documentation

Detailed reference, every builder method, every ox_target / qtarget export, return
values and edge cases are in **[DOCS.md](DOCS.md)**.

-

## License

MIT — do what you want, no warranty.
