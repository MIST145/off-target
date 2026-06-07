ContextMenu = {}

ContextMenu.Params = {
    EntityType = { world = 0, ped = 1, vehicle = 2, object = 3 },
    lastEntity = nil,
    lastWorldPosition = nil,
    active = false,
    registeredCallbacks = {},
}

local function ReleaseFocus()
    ContextMenu.Params.active = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    DisablePlayerFiring(PlayerId(), false)
end

function ContextMenu.Toggle()
    if ContextMenu.Params.active then
        ReleaseFocus()
        SendNUIMessage({ action = 'nui:context-menu:visible', data = false })
        return
    end

    ContextMenu.Params.active = true
    SendNUIMessage({ action = 'nui:context-menu:visible', data = true })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SetCursorLocation(0.5, 0.5)

    while ContextMenu.Params.active do
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisablePlayerFiring(PlayerId(), true)

        if OxTargetMarkers then
            OxTargetMarkers.draw()
        end

        Wait(0)
    end
end

Keys.Register(Config.MenuKey, 'context-menu', 'Open the context menu', function()
    ContextMenu.Toggle()
end)

local function asText(value, fallback)
    if value == nil then return fallback end
    if type(value) == 'string' then return value end
    return tostring(value)
end

local build = nil

local function newBuild()
    return {
        items = {},
        count = 0,
        header = nil,
        callbacks = {},
        checkCallbacks = {},
    }
end

local function ensureBuild()
    if not build then
        build = newBuild()
    end
    return build
end

-- A value is "callable" if it is a real Lua function OR a FiveM funcref.
-- Funcrefs arrive across the export boundary as `type() == 'table'` whose
-- metatable is protected (getmetatable returns a string, not the table that
-- holds __call), so we must NOT rely on reading __call. Any function or table
-- value reaching here is the marshalled callback.
local function isCallable(v)
    local t = type(v)
    return t == 'function' or t == 'table'
end

function ContextMenu.SetHeader(name, icon)
    local b = ensureBuild()
    b.header = { name = asText(name, 'Menu'), icon = icon }
end

function ContextMenu.AddSeparator(parent)
    local b = ensureBuild()
    b.count = b.count + 1
    b.items[b.count] = {
        id = b.count,
        separator = true,
        parent = (parent and parent > 0) and parent or nil,
    }
    return b.count
end

function ContextMenu.AddSubmenu(parent, name, icon, style, headerName, description)
    local b = ensureBuild()
    b.count = b.count + 1
    local id = b.count
    local label = asText(name, 'Submenu')
    b.items[id] = {
        id = id, name = label, icon = icon, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = true, headerName = asText(headerName, label:upper()),
    }
    return id
end

function ContextMenu.AddItem(parent, name, icon, style, description)
    local b = ensureBuild()
    b.count = b.count + 1
    local id = b.count
    b.items[id] = {
        id = id, name = asText(name, 'Option'), icon = icon, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = false,
    }
    return id
end

function ContextMenu.AddCheckbox(parent, name, checked, icon, style, description)
    local b = ensureBuild()
    b.count = b.count + 1
    local id = b.count
    b.items[id] = {
        id = id, name = asText(name, 'Option'), icon = icon, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = false, checkable = true, checked = checked or false,
    }
    return id
end

function ContextMenu.AddInfo(parent, name, value, icon, style, description)
    local b = ensureBuild()
    b.count = b.count + 1
    local id = b.count
    b.items[id] = {
        id = id, name = asText(name, 'Info'), icon = icon,
        value = value ~= nil and asText(value) or nil, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = false,
    }
    return id
end

function ContextMenu.OnActivate(id, fn)
    local b = ensureBuild()
    if id and isCallable(fn) then
        b.callbacks[id] = fn
    end
end

function ContextMenu.OnValueChanged(id, fn)
    local b = ensureBuild()
    if id and isCallable(fn) then
        b.checkCallbacks[id] = fn
    end
end

function ContextMenu.Register(a, b)
    -- Accept both `exports['Off-Target'].Register(fn)` and, defensively,
    -- a call style that prepends self -> Register(self, fn).
    local callback = a
    if not isCallable(callback) and isCallable(b) then
        callback = b
    end
    if not isCallable(callback) then
        print('^1[off-target] Register called without a function callback^0')
        return
    end

    -- Tag each callback with the resource that registered it so we can drop
    -- its (now-dead) funcrefs when that resource stops/restarts. For internal
    -- callbacks (our own converters) GetInvokingResource() is nil, so we fall
    -- back to this resource's name.
    local owner = GetInvokingResource() or GetCurrentResourceName()

    table.insert(ContextMenu.Params.registeredCallbacks, {
        owner = owner,
        fn = callback,
    })
    return #ContextMenu.Params.registeredCallbacks
end

-- When a resource that registered menu callbacks stops (or restarts), its
-- function references become invalid. Remove them so we neither call dead
-- funcrefs nor accumulate duplicates when the resource starts again.
local function purgeResource(resourceName)
    local list = ContextMenu.Params.registeredCallbacks
    local removed = 0
    for i = #list, 1, -1 do
        if list[i].owner == resourceName then
            table.remove(list, i)
            removed = removed + 1
        end
    end
    return removed
end

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    purgeResource(resourceName)
end)

local SerializeChildren

local function SerializeItem(b, item)
    if item.separator then
        return { id = item._globalId, separator = true }
    end

    local data = {
        id = item._globalId, name = item.name, icon = item.icon,
        style = {}, value = item.value, description = item.description,
        checkable = item.checkable, checked = item.checked,
    }

    if type(item.style) == 'table' and item.style.color then
        data.style.color = item.style.color
    end

    if item.isSubmenu then
        data.child = SerializeChildren(b, item.id)
        table.insert(data.child, 1, { id = item._globalId * -1, name = item.headerName, header = true })
    end

    return data
end

function SerializeChildren(b, parentLocalId)
    local children = {}
    for lid = 1, b.count do
        local item = b.items[lid]
        if item and item.parent == parentLocalId then
            children[#children + 1] = SerializeItem(b, item)
        end
    end
    return children
end

local function BuildItems(b)
    local result = {}

    if b.header then
        result[#result + 1] = {
            id = 0, name = b.header.name,
            icon = b.header.icon, header = true,
        }
    end

    for lid = 1, b.count do
        local item = b.items[lid]
        if item and not item.parent then
            result[#result + 1] = SerializeItem(b, item)
        end
    end

    return result
end

local function DegreesToRadians(deg) return deg * math.pi / 180 end

local function RaycastScreen(screenPos, maxDistance, ignore)
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(0)
    local camFov = GetGameplayCamFov()
    local tempCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, camRot.x, camRot.y, camRot.z, camFov, 0, 2)
    local camRight, camForward, camUp, camPos2 = GetCamMatrix(tempCam)
    DestroyCam(tempCam, true)
    screenPos = vector2(screenPos.x - 0.5, screenPos.y - 0.5) * 2.0
    local fovRad = DegreesToRadians(camFov)
    local to = camPos2 + camForward + (camRight * screenPos.x * fovRad * GetAspectRatio(false) * 0.534375) - (camUp * screenPos.y * fovRad * 0.534375)
    local dir = (to - camPos2) * maxDistance
    local ep = camPos2 + dir
    local ray = StartShapeTestRay(camPos2.x, camPos2.y, camPos2.z, ep.x, ep.y, ep.z, -1, ignore, 0)
    local _, hit, worldPos, _, entity = GetShapeTestResult(ray)
    if hit ~= 1 then return false, vector3(0, 0, 0), 0 end

    worldPos = vector3(worldPos.x, worldPos.y, worldPos.z)

    if entity and entity ~= 0 then
        local ok, etype = pcall(GetEntityType, entity)
        if not ok or etype == 0 or not DoesEntityExist(entity) then
            entity = 0
        end
    else
        entity = 0
    end

    return true, worldPos, entity
end

local activeCallbacks = {}
local activeCheckCallbacks = {}

RegisterNUICallback('ContextMenuPosition', function(data, cb)
    local sx, sy = GetActiveScreenResolution()
    local x, y = data.x / sx, data.y / sy

    local markerZone = OxTargetMarkers and OxTargetMarkers.getAtScreen(x, y)

    local hitSomething, worldPos, entity
    if markerZone then
        hitSomething, worldPos, entity = true, markerZone.coords, 0
    else
        hitSomething, worldPos, entity = RaycastScreen(vector2(x, y), Config.RaycastDistance, nil)
    end

    ContextMenu.Params.markerZone = markerZone
    activeCallbacks = {}
    activeCheckCallbacks = {}
    ContextMenu.Params.lastEntity = entity
    ContextMenu.Params.lastWorldPosition = worldPos

    local entityType = (entity ~= 0) and GetEntityType(entity) or 0
    local allItems = {}
    local globalIdCounter = 0

    local dead = {}

    for cbIndex, registered in ipairs(ContextMenu.Params.registeredCallbacks) do
        build = newBuild()
        local b = build

        local success, err = xpcall(registered.fn, function(e)
            return debug.traceback(tostring(e), 2)
        end, entity, entityType, worldPos, hitSomething)

        build = nil

        if success and b.count > 0 then
            for lid = 1, b.count do
                local item = b.items[lid]
                if item then
                    globalIdCounter = globalIdCounter + 1
                    item._globalId = globalIdCounter
                    if b.callbacks[lid] then
                        activeCallbacks[globalIdCounter] = b.callbacks[lid]
                    end
                    if b.checkCallbacks[lid] then
                        activeCheckCallbacks[globalIdCounter] = b.checkCallbacks[lid]
                    end
                end
            end

            local builtItems = BuildItems(b)
            for _, builtItem in ipairs(builtItems) do
                allItems[#allItems + 1] = builtItem
            end
        elseif not success then
            -- A dead funcref (resource stopped without us catching the stop
            -- event yet) raises "Execution of function reference ... failed".
            -- Drop it so it never spams again.
            dead[#dead + 1] = cbIndex
            print(('^1[off-target] callback #%d (%s) failed and was removed:\n%s^0'):format(
                cbIndex, tostring(registered.owner), tostring(err)))
        end
    end

    -- Remove dead callbacks back-to-front to keep indices valid.
    for i = #dead, 1, -1 do
        table.remove(ContextMenu.Params.registeredCallbacks, dead[i])
    end

    cb(allItems)
end)

RegisterNUICallback('ContextMenuClose', function(_, cb)
    ReleaseFocus()
    cb(json.encode({ ok = true }))
end)

RegisterNUICallback('ContextMenuButtonClick', function(data, cb)
    ReleaseFocus()
    local callback = activeCallbacks[data.id]
    if callback then callback(ContextMenu.Params.lastEntity, ContextMenu.Params.lastWorldPosition) end
    cb(json.encode({ ok = true }))
end)

RegisterNUICallback('ContextMenuCheckToggle', function(data, cb)
    local callback = activeCheckCallbacks[data.id]
    if callback then callback(data.checked, ContextMenu.Params.lastEntity, ContextMenu.Params.lastWorldPosition) end
    cb(json.encode({ ok = true }))
end)

-- Exports List
exports('Register', ContextMenu.Register)
exports('SetHeader', ContextMenu.SetHeader)
exports('AddSeparator', ContextMenu.AddSeparator)
exports('AddSubmenu', ContextMenu.AddSubmenu)
exports('AddItem', ContextMenu.AddItem)
exports('AddCheckbox', ContextMenu.AddCheckbox)
exports('AddInfo', ContextMenu.AddInfo)
exports('OnActivate', ContextMenu.OnActivate)
exports('OnValueChanged', ContextMenu.OnValueChanged)
exports('Toggle', function() return ContextMenu.Toggle() end)

-- Fired when Off-Target (re)starts. Resources that registered menus can listen
-- to this and re-run their ContextMenu:Register(...) calls so their menus come
-- back after an Off-Target restart (without restarting their own resource):
--   AddEventHandler('off-target:ready', function() ... end)
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerEvent('off-target:ready')
end)
