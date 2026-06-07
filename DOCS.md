# Off-Target — Documentation

Complete reference for the `Off-Target` menu exports and the `ox_target` /
`qtarget` compatibility layers.

> For a flat, copy-paste list of every export see **[exports.md](exports.md)**.

- [Concepts](#concepts)
- [Lifecycle](#lifecycle)
- [Menu API — Off-Target exports](#menu-api--off-target-exports)
  - [Register](#register)
  - [Building entries](#building-entries)
  - [Attaching behaviour](#attaching-behaviour)
  - [Styling & icons](#styling--icons)
- [Registration cleanup](#registration-cleanup)
- [ox_target compatibility layer](#ox_target-compatibility-layer)
  - [Global targets](#global-targets)
  - [Models](#models)
  - [Entities](#entities)
  - [Zones](#zones)
  - [Disabling targeting](#disabling-targeting)
  - [Option schema](#option-schema)
  - [Action resolution order](#action-resolution-order)
- [Behaviour & limitations](#behaviour--limitations)
- [Troubleshooting](#troubleshooting)

-

## Concepts

| Term | Meaning |
| --- | --- |
| **Hit** | Result of the screen raycast on right-click. |
| **Entity** | The entity under the cursor (`0` if none). |
| **Entity type** | `0` world, `1` ped, `2` vehicle, `3` object. |
| **World position** | World coordinates of the hit point (`vector3`). |
| **Item id** | The number returned by an `Add*` export, used as a parent or in `OnActivate`. |
| **Target / Option** | A single actionable entry registered via `ox_target` / `qtarget`. |

The menu is **rebuilt on every right-click**. Nothing is cached between opens,
so menus always reflect live game state (lock status, ownership, distance…).

The menu API is **flat and ID-based**: you add entries, you get ids back, and you
attach behaviour to those ids. No object with methods is passed across the
resource boundary — that is what makes it reliable from any resource.

-

## Lifecycle

```
Hold Config.MenuKey
        │
        ▼
NUI cursor shown ──► right-click
        │
        ▼
RaycastScreen() ──► hit, worldPos, entity
        │
        ▼
For each registered callback:
    callback(entity, entityType, worldPos, hit)
        │  (the callback calls AddItem / OnActivate / ... )
        ▼
All entries merged ──► sent to NUI ──► rendered
        │
        ▼
Click item ──► its OnActivate handler runs ──► menu closes
```

-

## Menu API — Off-Target exports

Grab the resource exports once:

```lua
local ContextMenu = exports['Off-Target']
```

### Register

```lua
local index = ContextMenu:Register(function(entity, entityType, worldPos, hit)
    -- build the menu here
end)
```

| Param | Type | Description |
| --- | --- | --- |
| `entity` | number | Entity under cursor (`0` if none). |
| `entityType` | number | `0` world · `1` ped · `2` vehicle · `3` object. |
| `worldPos` | vector3 | World hit position. |
| `hit` | boolean | `true` if the ray hit something. |

**Returns** the callback index. Returning early (`if not hit then return end`)
or adding no entries simply contributes nothing to the menu.

> Errors inside a callback are caught and printed as `^1[off-target] ...^0`;
> they never break other callbacks. A dead callback (its resource stopped) is
> removed automatically.

### Building entries

All `parent` arguments take an **item id** (the return value of `AddSubmenu`) or
`0` for the root menu. Each `Add*` export returns a numeric id.

#### `SetHeader(name, icon)`
Sets the menu title row.

```lua
ContextMenu:SetHeader('Vehicle', 'fa-solid fa-car')
```

#### `AddItem(parent, name, icon, style, description) → id`
A clickable entry. Attach the action with `OnActivate`.

```lua
local open = ContextMenu:AddItem(0, 'Open trunk', 'fa-solid fa-box', { color = { 99, 102, 241 } }, 'Opens the trunk.')
ContextMenu:OnActivate(open, function(entity, coords)
    -- ...
end)
```

| Param | Type | Notes |
| --- | --- | --- |
| `parent` | number | `0` for root, or a submenu id. |
| `name` | string | Label. |
| `icon` | string | Font Awesome class. |
| `style` | table | `{ color = { r, g, b } }`. |
| `description` | string | Shown on hover. |

#### `AddCheckbox(parent, name, checked, icon, style, description) → id`
A toggle. The handler fires **without closing** the menu.

```lua
local engine = ContextMenu:AddCheckbox(0, 'Engine', IsVehicleEngineOn(veh), 'fa-solid fa-power-off')
ContextMenu:OnValueChanged(engine, function(checked, entity)
    SetVehicleEngineOn(entity, checked, false, true)
end)
```

#### `AddSubmenu(parent, name, icon, style, headerName, description) → id`
A nested menu. Use the returned id as the `parent` of child entries.
`headerName` defaults to `name:upper()`.

```lua
local doors = ContextMenu:AddSubmenu(0, 'Doors', 'fa-solid fa-door-open', nil, 'DOORS')

local lock = ContextMenu:AddItem(doors, 'Lock', 'fa-solid fa-lock')
ContextMenu:OnActivate(lock, function(e) SetVehicleDoorsLocked(e, 2) end)

local unlock = ContextMenu:AddItem(doors, 'Unlock', 'fa-solid fa-lock-open')
ContextMenu:OnActivate(unlock, function(e) SetVehicleDoorsLocked(e, 1) end)
```

#### `AddInfo(parent, name, value, icon, style, description) → id`
A read-only row. If `value` is set, clicking **copies it to the clipboard**.

```lua
ContextMenu:AddInfo(0, 'Plate', GetVehicleNumberPlateText(veh), 'fa-solid fa-id-card')
```

#### `AddSeparator(parent) → id`
A horizontal divider.

```lua
ContextMenu:AddSeparator(0)
```

### Attaching behaviour

| Export | Handler signature |
| --- | --- |
| `OnActivate(id, fn)` | `(entity, worldPos)` |
| `OnValueChanged(id, fn)` | `(checked, entity, worldPos)` |

`entity` and `worldPos` are the values captured at right-click time.

### Styling & icons

- **Icons** use [Font Awesome 6](https://fontawesome.com/search) free classes,
  e.g. `'fa-solid fa-car'`, `'fa-regular fa-eye'`.
- **Colors** are `{ r, g, b }` (0–255) and tint the icon + label.

```lua
style = { color = { 239, 68, 68 } } -- red
```

-

## Registration cleanup

Every registration is tagged with the resource that made it.

- When that resource **stops or restarts**, its callbacks, options and zones are
  removed automatically. No dead function references, no duplicates on restart.
- When **Off-Target itself** restarts, other resources lose their registrations.
  Re-register on the `off-target:ready` event:

```lua
AddEventHandler('off-target:ready', function()
    -- re-run your ContextMenu:Register(...) / ox_target / qtarget calls
end)
```

-

## ox_target compatibility layer

These exports mirror [ox_target](https://overextended.dev/ox_target).

> ⚠️ **Rename the resource to `ox_target`** if you want the `ox_target`
> integration. Scripts call `exports.ox_target:*`, which resolves by **resource
> name** — so the folder must be named `ox_target` (and the real `ox_target`
> must be removed). The `provide 'ox_target'` line alone is **not** enough for
> export resolution. The **qtarget** layer (`exports.qtarget:*`) works regardless
> of the folder name and does not require renaming.

All `add*` functions accept either a **single option table** or an **array of
option tables**.

### Global targets

Applied to every entity of that class.

```lua
exports.ox_target:addGlobalPlayer(options)        -- every player (self + others)
exports.ox_target:addGlobalSelfPlayer(options)    -- only yourself
exports.ox_target:addGlobalOtherPlayer(options)   -- only other players
exports.ox_target:addGlobalPed(options)
exports.ox_target:addGlobalVehicle(options)
exports.ox_target:addGlobalObject(options)

exports.ox_target:removeGlobalPlayer(names)        -- names: string | string[] | nil
exports.ox_target:removeGlobalSelfPlayer(names)
exports.ox_target:removeGlobalOtherPlayer(names)
exports.ox_target:removeGlobalPed(names)
exports.ox_target:removeGlobalVehicle(names)
exports.ox_target:removeGlobalObject(names)

exports.ox_target:addGlobalOption(options)         -- shows on every right-click hit
exports.ox_target:removeGlobalOption(names)
```

Passing `nil` to a `remove*` clears **all** options of that class.

#### Player targeting scope

- `addGlobalPlayer` — options show on **every** player (yourself and others).
- `addGlobalSelfPlayer` — options show **only when targeting yourself**.
- `addGlobalOtherPlayer` — options show **only on other players**, never yourself.

Through the **qtarget** compatibility layer, the scope is selected with the
`type` field on `:Player(...)`:

```lua
-- only other players
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

### Models

Match by model name (string, hashed automatically) or hash.

```lua
exports.ox_target:addModel('prop_atm_01', options)
exports.ox_target:addModel({ 'prop_atm_01', 'prop_atm_02' }, options)
exports.ox_target:removeModel({ 'prop_atm_01' }, 'use_atm')
```

### Entities

```lua
-- Networked entities (by network id)
exports.ox_target:addEntity(netId, options)
exports.ox_target:addEntity({ netId1, netId2 }, options)
exports.ox_target:removeEntity(netId, names)

-- Local / non-networked entities (by handle)
exports.ox_target:addLocalEntity(entity, options)
exports.ox_target:addLocalEntity({ ped1, ped2 }, options)
exports.ox_target:removeLocalEntity(entity, names)
```

### Zones

Each `add*Zone` returns a **zone id** for `removeZone`.

```lua
local sphere = exports.ox_target:addSphereZone({
    coords  = vector3(195.0, -933.0, 30.0),
    radius  = 2.0,
    options = { { name = 'shop', label = 'Open shop', onSelect = openShop } },
})

local box = exports.ox_target:addBoxZone({
    coords  = vector3(-1037.0, -2738.0, 20.0),
    size    = vector3(3.0, 3.0, 2.0),
    options = { ... },
})

local poly = exports.ox_target:addPolyZone({
    points  = { vector3(0,0,0), vector3(5,0,0), vector3(5,5,0), vector3(0,5,0) },
    minZ    = 29.0,
    maxZ    = 33.0,
    options = { ... },
})

exports.ox_target:removeZone(sphere)
```

| Zone | Params |
| --- | --- |
| `addSphereZone` | `coords`, `radius` (default `2.0`), `options` |
| `addBoxZone` | `coords`, `size` (vector3, default `2,2,2`), `options` |
| `addPolyZone` | `points` (vector3[]), `minZ`, `maxZ`, `options` (`coords` optional — auto-computed from points) |

A zone option shows when the **hit world position** is inside the zone.

#### Zone markers

Every zone can draw an on-screen marker you can click directly (no need to point
at geometry). Markers are optional and configured per zone:

```lua
exports.ox_target:addSphereZone({
    coords       = vector3(195.0, -933.0, 30.0),
    radius       = 2.0,
    marker       = true,                  -- draw a marker (default true)
    markerRadius = 20,                    -- click radius in pixels (default Config.MarkerClickRadius)
    markerColor  = { 99, 102, 241 },      -- {r,g,b} or {r,g,b,a} (default grey)
    distance     = 10.0,                  -- max draw distance (default Config.MarkerDrawDistance)
    options      = { ... },
})
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `marker` | boolean | `true` | Draw a marker for this zone. Set `false` to hide. |
| `markerRadius` | number | `Config.MarkerClickRadius` | Click radius in pixels. |
| `markerColor` | `{r,g,b[,a]}` | grey `155,155,155,175` | Marker tint. |
| `distance` | number | `Config.MarkerDrawDistance` | Max distance the marker is drawn. |

A marker only draws while the zone has at least one option.

### Disabling targeting

```lua
exports.ox_target:disableTargeting(true)  -- suppress all ox_target options
exports.ox_target:disableTargeting(false)
```

Off-Target `Register` callbacks are **not** affected by this flag.

### Option schema

```lua
{
    name        = 'unique_id',          -- required for remove*
    label       = 'Shown text',
    icon        = 'fa-solid fa-gear',
    iconColor   = { 99, 102, 241 },     -- {r,g,b}
    distance    = 3.0,                  -- default 7.0
    description = 'Hover text',

    canInteract = function(entity, distance, coords, name, bone)
        return true                      -- false/nil hides the option
    end,

    -- one action:
    onSelect    = function(data) end,
    event       = 'client:event',
    serverEvent = 'server:event',
    command     = 'somecommand',
    export      = 'resource.function',
}
```

`data` passed to actions:

```lua
{ entity = <number>, coords = <vector3>, distance = <number> }
```

### Action resolution order

When an option is clicked, the **first** present field wins, in this order:

1. `onSelect(data)`
2. `export` → `exports[resource][fn](data)`
3. `event` → `TriggerEvent(event, data)`
4. `serverEvent` → `TriggerServerEvent(serverEvent, data)`
5. `command` → `ExecuteCommand(command)`

-

## Behaviour & limitations

- **`groups` and `items`** option fields are accepted but **not enforced** —
  there is no framework / inventory dependency. Use `canInteract` for gating.
- **`bones`** are not used; the raycast resolves the whole entity.
- Distance is measured from the player ped to the **hit point**, not the entity
  origin.
- The menu paginates root items past `Config.ItemsPerPage`; submenus do not
  paginate.
- Networked entity matching uses the entity's current network id at click time.

-

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Menu never opens | UI not built — run `npm run build` in `web/`. |
| `exports.ox_target` is nil | This resource isn't started, or the real `ox_target` is also running (remove it). |
| Option never shows | `distance` too small, `canInteract` returned false, or wrong entity class export. |
| Icons are blank squares | Font Awesome class is wrong; check it on fontawesome.com. |
| Clicking does nothing | The option has no action field, or the callback errored (check `F8` console). |
| `remove*` did nothing | `name` mismatch — names must match exactly. |
| `Register called without a function callback` | The argument passed to `Register` was not a function. |
| `Execution of function reference ... failed` | A registered callback's resource stopped without restarting. Off-Target removes it automatically; restart your resource (or use `off-target:ready`) to re-add it. |
| Entries duplicated after restart | Make sure you `ensure`/`restart` your resource (not `start` twice). Off-Target de-duplicates by removing a resource's registrations when it stops. |

-

## Credits

- **[Kiminaze — ContextMenu](https://github.com/Kiminaze/ContextMenu)** — the
  original right-click context menu and the flat, ID-based export pattern this
  resource follows.
- **[ox_target](https://github.com/overextended/ox_target)** (Overextended) —
  mirrored by the `ox_target` compatibility layer.
- **[qtarget](https://github.com/overextended/qtarget)** — mirrored by the
  `qtarget` compatibility layer.
