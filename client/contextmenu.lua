ContextMenu = {}

ContextMenu.Params = {
    EntityType = { world = 0, ped = 1, vehicle = 2, object = 3 },
    lastEntity = nil,
    lastWorldPosition = nil,
    active = false,
    registeredCallbacks = {},
}

function ContextMenu.Toggle()
    ContextMenu.Params.active = not ContextMenu.Params.active

    SendNUIMessage({ action = 'nui:context-menu:visible', data = ContextMenu.Params.active })
    SetNuiFocus(ContextMenu.Params.active, ContextMenu.Params.active)
    SetNuiFocusKeepInput(ContextMenu.Params.active)

    if ContextMenu.Params.active then SetCursorLocation(0.5, 0.5) end

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

function ContextMenu.Register(callback)
    table.insert(ContextMenu.Params.registeredCallbacks, callback)
    return #ContextMenu.Params.registeredCallbacks
end

local BuilderMethods = {}
BuilderMethods.__index = BuilderMethods

local function CreateBuilder()
    local self = setmetatable({}, BuilderMethods)
    self._items = {}
    self._count = 0
    self._header = nil
    self._callbacks = {}
    self._checkCallbacks = {}
    return self
end

function BuilderMethods:SetHeader(name, icon)
    self._header = { name = name, icon = icon }
end

function BuilderMethods:AddSeparator(parent)
    self._count = self._count + 1
    self._items[self._count] = {
        id = self._count,
        separator = true,
        parent = (parent and parent > 0) and parent or nil,
    }
    return self._count
end

function BuilderMethods:AddSubmenu(parent, name, icon, style, headerName, description)
    self._count = self._count + 1
    local id = self._count
    self._items[id] = {
        id = id, name = name, icon = icon, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = true, headerName = headerName or name:upper(),
    }
    return id
end

function BuilderMethods:AddItem(parent, name, callback, icon, style, description)
    self._count = self._count + 1
    local id = self._count
    self._items[id] = {
        id = id, name = name, icon = icon, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = false,
    }
    if callback then self._callbacks[id] = callback end
    return id
end

function BuilderMethods:AddCheckbox(parent, name, checked, callback, icon, style, description)
    self._count = self._count + 1
    local id = self._count
    self._items[id] = {
        id = id, name = name, icon = icon, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = false, checkable = true, checked = checked or false,
    }
    if callback then self._checkCallbacks[id] = callback end
    return id
end

function BuilderMethods:AddInfo(parent, name, value, icon, style, description)
    self._count = self._count + 1
    local id = self._count
    self._items[id] = {
        id = id, name = name, icon = icon, value = value, description = description,
        style = style or {}, parent = (parent and parent > 0) and parent or nil,
        isSubmenu = false,
    }
    return id
end

function BuilderMethods:Build()
    local result = {}

    if self._header then
        table.insert(result, {
            id = 0, name = self._header.name,
            icon = self._header.icon, header = true,
        })
    end

    local function GetChildren(parentLocalId)
        local children = {}
        for lid = 1, self._count do
            local item = self._items[lid]
            if item and item.parent == parentLocalId then
                if item.separator then
                    table.insert(children, { id = item._globalId, separator = true })
                else
                    local data = {
                        id = item._globalId, name = item.name, icon = item.icon,
                        style = {}, value = item.value, description = item.description,
                        checkable = item.checkable, checked = item.checked,
                    }
                    if item.style and item.style.color then data.style.color = item.style.color end
                    if item.isSubmenu then
                        data.child = GetChildren(lid)
                        table.insert(data.child, 1, { id = item._globalId * -1, name = item.headerName, header = true })
                    end
                    table.insert(children, data)
                end
            end
        end
        return children
    end

    for lid = 1, self._count do
        local item = self._items[lid]
        if item and not item.parent then
            if item.separator then
                table.insert(result, { id = item._globalId, separator = true })
            else
                local data = {
                    id = item._globalId, name = item.name, icon = item.icon,
                    style = {}, value = item.value, description = item.description,
                    checkable = item.checkable, checked = item.checked,
                }
                if item.style and item.style.color then data.style.color = item.style.color end
                if item.isSubmenu then
                    data.child = GetChildren(lid)
                    table.insert(data.child, 1, { id = item._globalId * -1, name = item.headerName, header = true })
                end
                table.insert(result, data)
            end
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
    if hit ~= 1 then return false, vector3(0, 0, 0), nil end

    worldPos = vector3(worldPos.x, worldPos.y, worldPos.z)

    if entity and entity ~= 0 then
        local ok, etype = pcall(GetEntityType, entity)
        if not ok or etype == 0 or not DoesEntityExist(entity) then
            entity = nil
        end
    else
        entity = nil
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

    local entityType = GetEntityType(entity)
    local allItems = {}
    local globalIdCounter = 0

    for _, registeredCb in ipairs(ContextMenu.Params.registeredCallbacks) do
        local builder = CreateBuilder()
        local success, err = pcall(registeredCb, builder, entity, entityType, worldPos, hitSomething)

        if success and builder._count > 0 then
            for lid = 1, builder._count do
                local item = builder._items[lid]
                if item then
                    globalIdCounter = globalIdCounter + 1
                    item._globalId = globalIdCounter
                    if builder._callbacks[lid] then
                        activeCallbacks[globalIdCounter] = builder._callbacks[lid]
                    end
                    if builder._checkCallbacks[lid] then
                        activeCheckCallbacks[globalIdCounter] = builder._checkCallbacks[lid]
                    end
                end
            end

            local builtItems = builder:Build()
            for _, builtItem in ipairs(builtItems) do
                table.insert(allItems, builtItem)
            end
        elseif not success then
            print(('^1[off-target] %s^0'):format(tostring(err)))
        end
    end

    cb(allItems)
end)

RegisterNUICallback('ContextMenuClose', function(_, cb)
    ContextMenu.Params.active = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    DisablePlayerFiring(PlayerId(), false)
    cb(json.encode({ ok = true }))
end)

RegisterNUICallback('ContextMenuButtonClick', function(data, cb)
    ContextMenu.Params.active = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    DisablePlayerFiring(PlayerId(), false)
    local callback = activeCallbacks[data.id]
    if callback then callback(ContextMenu.Params.lastEntity, ContextMenu.Params.lastWorldPosition) end
    cb(json.encode({ ok = true }))
end)

RegisterNUICallback('ContextMenuCheckToggle', function(data, cb)
    local callback = activeCheckCallbacks[data.id]
    if callback then callback(data.checked, ContextMenu.Params.lastEntity, ContextMenu.Params.lastWorldPosition) end
    cb(json.encode({ ok = true }))
end)

exports('ContextMenu', function() return ContextMenu end)
