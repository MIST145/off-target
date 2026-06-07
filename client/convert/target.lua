OxTarget = {}

local globalOtherPlayer = {}
local globalSelfPlayer = {}
local globalPlayer = {}
local globalPed = {}
local globalVehicle = {}
local globalObject = {}
local globalOptions = {}
local models = {}
local localEntities = {}
local networkEntities = {}
local zones = {}

local zoneIdCounter = 0
local targetingDisabled = false

local ensureList = Convert.ensureList
local tableInsertList = Convert.tableInsertList
local removeByNames = Convert.removeByNames
local toVec3 = Convert.toVec3

local function resolveModelKey(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local ok, model = pcall(GetEntityModel, entity)
    if not ok then return nil end
    return model
end

local function canInteract(option, entity, distance, coords, name, bone)
    if option.canInteract then
        local ok, result = pcall(option.canInteract, entity, distance, coords, name, bone)
        if not ok then return false end
        return result ~= false
    end
    return true
end

local function withinDistance(option, distance)
    local max = option.distance or 7.0
    return distance <= max
end

local function triggerOption(option, entity, coords)
    local data = {
        entity = entity,
        coords = coords,
        distance = #(GetEntityCoords(PlayerPedId()) - coords),
    }

    if option.onSelect then
        option.onSelect(data)
    elseif option.export then
        local resource, fn = option.export:match('([^%.]+)%.([^%.]+)')
        if resource and fn then exports[resource][fn](data) end
    elseif option.event then
        TriggerEvent(option.event, data)
    elseif option.serverEvent then
        TriggerServerEvent(option.serverEvent, data)
    elseif option.command then
        ExecuteCommand(option.command)
    end
end

local function collectOptions(out, list, entity, coords, distance)
    for _, option in ipairs(list) do
        if withinDistance(option, distance)
            and canInteract(option, entity, distance, coords, option.name, nil) then
            out[#out + 1] = option
        end
    end
end

ContextMenu.Register(function(entity, entityType, worldPos, hit)
    if targetingDisabled or not hit then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - worldPos)
    local matched = {}

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        local model = resolveModelKey(entity)

        if model and models[model] then
            collectOptions(matched, models[model], entity, worldPos, distance)
        end

        if NetworkGetEntityIsNetworked(entity) then
            local netId = NetworkGetNetworkIdFromEntity(entity)
            if networkEntities[netId] then
                collectOptions(matched, networkEntities[netId], entity, worldPos, distance)
            end
        end

        if localEntities[entity] then
            collectOptions(matched, localEntities[entity], entity, worldPos, distance)
        end

        if entityType == 1 then
            local isPlayer = IsPedAPlayer(entity)
            if isPlayer and entity == PlayerPedId() then
                collectOptions(matched, globalSelfPlayer, entity, worldPos, distance)
                collectOptions(matched, globalPlayer, entity, worldPos, distance)
            elseif isPlayer then
                collectOptions(matched, globalOtherPlayer, entity, worldPos, distance)
                collectOptions(matched, globalPlayer, entity, worldPos, distance)
            else
                collectOptions(matched, globalPed, entity, worldPos, distance)
            end
        elseif entityType == 2 then
            collectOptions(matched, globalVehicle, entity, worldPos, distance)
        elseif entityType == 3 then
            collectOptions(matched, globalObject, entity, worldPos, distance)
        end
    end

    for _, zone in pairs(zones) do
        if zone:contains(worldPos) then
            collectOptions(matched, zone.options, entity, worldPos, distance)
        end
    end

    collectOptions(matched, globalOptions, entity, worldPos, distance)

    if #matched == 0 then return end

    for _, option in ipairs(matched) do
        local style = option.iconColor and { color = option.iconColor } or nil
        local id = ContextMenu.AddItem(0, option.label or option.name or 'Option', option.icon, style, option.description)
        ContextMenu.OnActivate(id, function(ent, coords)
            triggerOption(option, ent, coords or worldPos)
        end)
    end
end)

function OxTarget.addGlobalPlayer(options) tableInsertList(globalPlayer, options) end
function OxTarget.addGlobalSelfPlayer(options) tableInsertList(globalSelfPlayer, options) end
function OxTarget.addGlobalOtherPlayer(options) tableInsertList(globalOtherPlayer, options) end
function OxTarget.addGlobalPed(options) tableInsertList(globalPed, options) end
function OxTarget.addGlobalVehicle(options) tableInsertList(globalVehicle, options) end
function OxTarget.addGlobalObject(options) tableInsertList(globalObject, options) end
function OxTarget.addGlobalOption(options) tableInsertList(globalOptions, options) end

function OxTarget.removeGlobalPlayer(names) removeByNames(globalPlayer, names) end
function OxTarget.removeGlobalSelfPlayer(names) removeByNames(globalSelfPlayer, names) end
function OxTarget.removeGlobalOtherPlayer(names) removeByNames(globalOtherPlayer, names) end
function OxTarget.removeGlobalPed(names) removeByNames(globalPed, names) end
function OxTarget.removeGlobalVehicle(names) removeByNames(globalVehicle, names) end
function OxTarget.removeGlobalObject(names) removeByNames(globalObject, names) end
function OxTarget.removeGlobalOption(names) removeByNames(globalOptions, names) end

function OxTarget.addModel(input, options)
    for _, m in ipairs(ensureList(input)) do
        local key = type(m) == 'string' and joaat(m) or m
        models[key] = models[key] or {}
        tableInsertList(models[key], options)
    end
end

function OxTarget.removeModel(input, names)
    for _, m in ipairs(ensureList(input)) do
        local key = type(m) == 'string' and joaat(m) or m
        if models[key] then removeByNames(models[key], names) end
    end
end

function OxTarget.addEntity(input, options)
    for _, netId in ipairs(ensureList(input)) do
        networkEntities[netId] = networkEntities[netId] or {}
        tableInsertList(networkEntities[netId], options)
    end
end

function OxTarget.removeEntity(input, names)
    for _, netId in ipairs(ensureList(input)) do
        if networkEntities[netId] then removeByNames(networkEntities[netId], names) end
    end
end

function OxTarget.addLocalEntity(input, options)
    for _, ent in ipairs(ensureList(input)) do
        localEntities[ent] = localEntities[ent] or {}
        tableInsertList(localEntities[ent], options)
    end
end

function OxTarget.removeLocalEntity(input, names)
    for _, ent in ipairs(ensureList(input)) do
        if localEntities[ent] then removeByNames(localEntities[ent], names) end
    end
end

local function registerZone(zone, params)
    zoneIdCounter = zoneIdCounter + 1
    zone.id = zoneIdCounter
    zone.options = zone.options or {}
    zone.coords = toVec3(params.coords or zone.coords)
    zone.marker = params.marker ~= false
    zone.markerRadius = params.markerRadius or Config.MarkerClickRadius
    zone.markerColor = params.markerColor
    zone.distance = params.distance or Config.MarkerDrawDistance
    zone._owner = Convert.currentOwner()
    zones[zoneIdCounter] = zone
    return zoneIdCounter
end

function OxTarget.addSphereZone(params)
    local coords = toVec3(params.coords)
    local radius = params.radius or 2.0
    local zone = {
        coords = coords,
        options = params.options,
        contains = function(_, point) return #(coords - point) <= radius end,
    }
    return registerZone(zone, params)
end

function OxTarget.addBoxZone(params)
    local coords = toVec3(params.coords)
    local size = toVec3(params.size or vector3(2.0, 2.0, 2.0))
    local half = size / 2.0
    local zone = {
        coords = coords,
        options = params.options,
        contains = function(_, point)
            local d = point - coords
            return math.abs(d.x) <= half.x and math.abs(d.y) <= half.y and math.abs(d.z) <= half.z
        end,
    }
    return registerZone(zone, params)
end

function OxTarget.addPolyZone(params)
    local points = params.points
    local minZ = params.minZ
    local maxZ = params.maxZ

    local center = toVec3(params.coords)
    if not center and points and #points > 0 then
        local sx, sy, sz = 0.0, 0.0, 0.0
        for i = 1, #points do
            sx, sy, sz = sx + points[i].x, sy + points[i].y, sz + points[i].z
        end
        local z = ((minZ or 0) + (maxZ or 0)) / 2.0
        if z == 0 then z = sz / #points end
        center = vector3(sx / #points, sy / #points, z)
    end

    local zone = {
        coords = center,
        options = params.options,
        contains = function(_, point)
            if minZ and point.z < minZ then return false end
            if maxZ and point.z > maxZ then return false end
            local inside = false
            local j = #points
            for i = 1, #points do
                local pi, pj = points[i], points[j]
                if ((pi.y > point.y) ~= (pj.y > point.y))
                    and (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) then
                    inside = not inside
                end
                j = i
            end
            return inside
        end,
    }
    return registerZone(zone, params)
end

function OxTarget.removeZone(id)
    zones[id] = nil
end

local markerDict, markerTexture = 'shared', 'emptydot_32'
local fbDict, fbTexture = 'commonmenu', 'common_medal'

local markerSpriteReady = nil
local markerDeadline = 0

local function ensureMarkerTexture()
    if markerSpriteReady == true then return true end

    if markerSpriteReady == nil then
        markerSpriteReady = false
        markerDeadline = GetGameTimer() + 3000
        RequestStreamedTextureDict(markerDict, false)
    end

    if HasStreamedTextureDictLoaded(markerDict) then
        markerSpriteReady = true
        return true
    end

    return false
end

local function getMarkerScreenPos(zone, playerCoords)
    local coords = zone.coords
    if not coords then return false, 0.0, 0.0, 0.0 end

    local distance = #(playerCoords - coords)
    if distance > (zone.distance or Config.MarkerDrawDistance) then
        return false, 0.0, 0.0, distance
    end

    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return false, 0.0, 0.0, distance end

    return true, sx, sy, distance
end

local function markerColor(zone)
    local c = zone.markerColor
    if not c then return 155, 155, 155, 175 end
    return c[1] or c.r or 155, c[2] or c.g or 155, c[3] or c.b or 155, c[4] or c.a or 175
end

function OxTarget.drawZoneMarkers()
    if targetingDisabled then return end

    local useSprite = ensureMarkerTexture()
    local waiting = not useSprite and GetGameTimer() < markerDeadline
    if waiting then return end

    if not useSprite then
        RequestStreamedTextureDict(fbDict, false)
        if not HasStreamedTextureDictLoaded(fbDict) then return end
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local aspect = GetAspectRatio(false)
    local width = useSprite and 0.014 or 0.02
    local height = width * aspect

    for _, zone in pairs(zones) do
        if zone.marker and zone.coords and #zone.options > 0 then
            local onScreen, sx, sy = getMarkerScreenPos(zone, playerCoords)
            if onScreen then
                local r, g, b, a = markerColor(zone)
                if useSprite then
                    DrawSprite(markerDict, markerTexture, sx, sy, width, height, 0.0, r, g, b, a)
                else
                    DrawSprite(fbDict, fbTexture, sx, sy, width, height, 0.0, r, g, b, a)
                end
            end
        end
    end
end

function OxTarget.getMarkerAtScreen(nx, ny)
    if targetingDisabled then return nil end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local sw, sh = GetActiveScreenResolution()
    local cursorX, cursorY = nx * sw, ny * sh

    local best, bestDist
    for _, zone in pairs(zones) do
        if zone.marker and zone.coords and #zone.options > 0 then
            local onScreen, sx, sy = getMarkerScreenPos(zone, playerCoords)
            if onScreen then
                local dx = sx * sw - cursorX
                local dy = sy * sh - cursorY
                local pixelDist = math.sqrt(dx * dx + dy * dy)
                local radius = zone.markerRadius or Config.MarkerClickRadius

                if pixelDist <= radius and (not bestDist or pixelDist < bestDist) then
                    best, bestDist = zone, pixelDist
                end
            end
        end
    end

    return best
end

function OxTarget.disableTargeting(state)
    targetingDisabled = state == true
end

-- Drop every option/zone that was added by a resource when it stops, so they
-- don't leak (and don't duplicate when the resource restarts and re-adds them).
local function purgeOwnerFromList(list, resourceName)
    for i = #list, 1, -1 do
        if list[i]._owner == resourceName then
            table.remove(list, i)
        end
    end
end

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end

    purgeOwnerFromList(globalPlayer, resourceName)
    purgeOwnerFromList(globalSelfPlayer, resourceName)
    purgeOwnerFromList(globalOtherPlayer, resourceName)
    purgeOwnerFromList(globalPed, resourceName)
    purgeOwnerFromList(globalVehicle, resourceName)
    purgeOwnerFromList(globalObject, resourceName)
    purgeOwnerFromList(globalOptions, resourceName)

    for _, list in pairs(models) do purgeOwnerFromList(list, resourceName) end
    for _, list in pairs(networkEntities) do purgeOwnerFromList(list, resourceName) end
    for _, list in pairs(localEntities) do purgeOwnerFromList(list, resourceName) end

    for id, zone in pairs(zones) do
        if zone._owner == resourceName then
            zones[id] = nil
        end
    end
end)

OxTargetMarkers = {
    draw = OxTarget.drawZoneMarkers,
    getAtScreen = OxTarget.getMarkerAtScreen,
}
