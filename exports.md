# Off-Target — Exports reference

Every export exposed by this resource, in one place.

- [Off-Target menu exports](#off-target-menu-exports)
- [ox_target compatibility exports](#ox_target-compatibility-exports)
- [qtarget compatibility exports](#qtarget-compatibility-exports)
- [Shared types](#shared-types)

All examples assume the resource folder is named `Off-Target`:

```lua
local ContextMenu = exports['Off-Target']
```

---

## Off-Target menu exports

These build the right-click menu. The flow is always the same: inside a
`Register` callback you add entries (each returns a numeric **id**), then attach
behaviour to those ids.

| Export | Returns | Purpose |
| --- | --- | --- |
| `Register(fn)` | number (callback index) | Register a menu-building callback. |
| `SetHeader(name, icon)` | — | Set the menu title row for the current build. |
| `AddItem(parent, name, icon, style, description)` | id | A clickable entry. |
| `AddCheckbox(parent, name, checked, icon, style, description)` | id | A toggle entry. |
| `AddSubmenu(parent, name, icon, style, headerName, description)` | id | A nested submenu. |
| `AddSeparator(parent)` | id | A horizontal divider. |
| `AddInfo(parent, name, value, icon, style, description)` | id | A read-only row (click copies `value`). |
| `OnActivate(id, fn)` | — | Attach a click handler to an item id. |
| `OnValueChanged(id, fn)` | — | Attach a change handler to a checkbox id. |
| `Toggle()` | — | Open / close the menu programmatically. |

`parent` is `0` for the root menu, or a submenu id returned by `AddSubmenu`.

### `Register(fn)`

```lua
ContextMenu:Register(function(entity, entityType, worldPos, hit)
    -- build the menu here
end)
```

| Callback param | Type | Description |
| --- | --- | --- |
| `entity` | number | Entity under the cursor (`0` if none). |
| `entityType` | number | `0` world · `1` ped · `2` vehicle · `3` object. |
| `worldPos` | vector3 | World hit position. |
| `hit` | boolean | `true` if the ray hit something. |

Returning early (`if not hit then return end`) or adding no entries simply
contributes nothing to the menu. Errors inside a callback are caught and
printed; they never break other callbacks.

### `SetHeader(name, icon)`

```lua
ContextMenu:SetHeader('Vehicle', 'fa-solid fa-car')
```

### `AddItem(parent, name, icon, style, description) → id`

```lua
local id = ContextMenu:AddItem(0, 'Open trunk', 'fa-solid fa-box', { color = { 99, 102, 241 } }, 'Opens the trunk.')
ContextMenu:OnActivate(id, function(entity, coords)
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

### `AddCheckbox(parent, name, checked, icon, style, description) → id`

The change handler fires **without closing** the menu.

```lua
local id = ContextMenu:AddCheckbox(0, 'Engine', IsVehicleEngineOn(veh), 'fa-solid fa-power-off')
ContextMenu:OnValueChanged(id, function(checked, entity, coords)
    SetVehicleEngineOn(entity, checked, false, true)
end)
```

### `AddSubmenu(parent, name, icon, style, headerName, description) → id`

Use the returned id as the `parent` of child entries. `headerName` defaults to
`name:upper()`.

```lua
local doors = ContextMenu:AddSubmenu(0, 'Doors', 'fa-solid fa-door-open', nil, 'DOORS')

local lock = ContextMenu:AddItem(doors, 'Lock', 'fa-solid fa-lock')
ContextMenu:OnActivate(lock, function(e) SetVehicleDoorsLocked(e, 2) end)

local unlock = ContextMenu:AddItem(doors, 'Unlock', 'fa-solid fa-lock-open')
ContextMenu:OnActivate(unlock, function(e) SetVehicleDoorsLocked(e, 1) end)
```

### `AddInfo(parent, name, value, icon, style, description) → id`

A read-only row. If `value` is set, clicking it **copies it to the clipboard**.

```lua
ContextMenu:AddInfo(0, 'Plate', GetVehicleNumberPlateText(veh), 'fa-solid fa-id-card')
```

### `AddSeparator(parent) → id`

```lua
ContextMenu:AddSeparator(0)
```

### `OnActivate(id, fn)` / `OnValueChanged(id, fn)`

| Source | Handler signature |
| --- | --- |
| `OnActivate` | `(entity, worldPos)` |
| `OnValueChanged` | `(checked, entity, worldPos)` |

`entity` and `worldPos` are the values captured at right-click time.

### `Toggle()`

```lua
exports['Off-Target']:Toggle()
```

Opens the menu if closed, closes it if open. Normally bound to the menu key, but
you can call it from your own logic.

---

## ox_target compatibility exports

Mirror of the [ox_target](https://github.com/overextended/ox_target) API. All
`add*` functions accept either a **single option table** or an **array** of them.
See [Shared types](#shared-types) for the option schema.

### Global targets

```lua
exports.ox_target:addGlobalPlayer(options)        -- every player (self + others)
exports.ox_target:addGlobalSelfPlayer(options)    -- only yourself
exports.ox_target:addGlobalOtherPlayer(options)   -- only other players
exports.ox_target:addGlobalPed(options)
exports.ox_target:addGlobalVehicle(options)
exports.ox_target:addGlobalObject(options)
exports.ox_target:addGlobalOption(options)        -- shows on every right-click hit

exports.ox_target:removeGlobalPlayer(names)        -- names: string | string[] | nil
exports.ox_target:removeGlobalSelfPlayer(names)
exports.ox_target:removeGlobalOtherPlayer(names)
exports.ox_target:removeGlobalPed(names)
exports.ox_target:removeGlobalVehicle(names)
exports.ox_target:removeGlobalObject(names)
exports.ox_target:removeGlobalOption(names)
```

Passing `nil` to a `remove*` clears **all** options of that class.

| Export | Shows on |
| --- | --- |
| `addGlobalPlayer` | every player (yourself **and** others) |
| `addGlobalSelfPlayer` | only yourself |
| `addGlobalOtherPlayer` | only other players |

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
| `addPolyZone` | `points` (vector3[]), `minZ`, `maxZ`, `options` (`coords` optional — auto-computed) |

A zone option shows when the **hit world position** is inside the zone.

#### Zone markers

Every zone can draw a clickable on-screen marker:

```lua
exports.ox_target:addSphereZone({
    coords       = vector3(195.0, -933.0, 30.0),
    radius       = 2.0,
    marker       = true,                  -- draw a marker (default true)
    markerRadius = 20,                    -- click radius in pixels
    markerColor  = { 99, 102, 241 },      -- {r,g,b} or {r,g,b,a}
    distance     = 10.0,                  -- max draw distance
    options      = { ... },
})
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `marker` | boolean | `true` | Draw a marker for this zone. |
| `markerRadius` | number | `Config.MarkerClickRadius` | Click radius in pixels. |
| `markerColor` | `{r,g,b[,a]}` | grey | Marker tint. |
| `distance` | number | `Config.MarkerDrawDistance` | Max draw distance. |

### Disabling targeting

```lua
exports.ox_target:disableTargeting(true)   -- suppress all ox_target / qtarget options
exports.ox_target:disableTargeting(false)
```

Off-Target `Register` callbacks are **not** affected by this flag.

---

## qtarget compatibility exports

Mirror of the legacy [qtarget](https://github.com/overextended/qtarget) API.
Option fields are converted automatically (`action` → `onSelect`, `job` →
`groups`, `item`/`required_item` → `items`, `event` + `type` → the matching
client/server/command action).

### Zones

```lua
exports.qtarget:AddBoxZone(name, center, length, width, options, targetoptions)
exports.qtarget:AddPolyZone(name, points, options, targetoptions)
exports.qtarget:AddCircleZone(name, center, radius, options, targetoptions)
exports.qtarget:RemoveZone(id)
```

### Globals

```lua
exports.qtarget:Ped(options)
exports.qtarget:Vehicle(options)
exports.qtarget:Object(options)
exports.qtarget:Player(options)        -- options.type: 'self' | 'other' | nil
exports.qtarget:Globals(options)

exports.qtarget:RemovePed(labels)
exports.qtarget:RemoveVehicle(labels)
exports.qtarget:RemoveObject(labels)
exports.qtarget:RemovePlayer(labels)
exports.qtarget:RemoveGlobals(labels)
```

`Player` routing by `type`:

| `type` | Routed to |
| --- | --- |
| `'self'` | `addGlobalSelfPlayer` |
| `'other'` | `addGlobalOtherPlayer` |
| omitted / other | `addGlobalPlayer` |

### Models, entities and bones

```lua
exports.qtarget:AddTargetModel(models, options)
exports.qtarget:RemoveTargetModel(models, labels)

exports.qtarget:AddTargetEntity(entities, options)     -- networked or local, auto-detected
exports.qtarget:RemoveTargetEntity(entities, labels)

exports.qtarget:AddTargetBone(bones, options)          -- mapped onto global vehicles
```

---

## Shared types

### Option schema (ox_target)

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

    -- one action (first present field wins):
    onSelect    = function(data) end,
    export      = 'resource.function',
    event       = 'client:event',
    serverEvent = 'server:event',
    command     = 'somecommand',
}
```

### Action `data`

The table passed to `onSelect` / `export` / `event` / `serverEvent`:

```lua
{ entity = <number>, coords = <vector3>, distance = <number> }
```

### Action resolution order

When an option is clicked, the **first** present field wins:

1. `onSelect(data)`
2. `export` → `exports[resource][fn](data)`
3. `event` → `TriggerEvent(event, data)`
4. `serverEvent` → `TriggerServerEvent(serverEvent, data)`
5. `command` → `ExecuteCommand(command)`

### Style

```lua
style = { color = { r, g, b } }   -- 0–255, tints the icon + label
```

Icons use [Font Awesome 6](https://fontawesome.com/search) free classes, e.g.
`'fa-solid fa-car'`, `'fa-regular fa-eye'`.
