local OxTarget = {}

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

local function tableInsertList(target, options)
    if options.name or options.label or options.onSelect or options.event or options.serverEvent or options.command or options.export then
        target[#target + 1] = options
        return
    end
    for i = 1, #options do
        target[#target + 1] = options[i]
    end
end

local function ensureList(value)
    if type(value) == 'table' then return value end
    return { value }
end

local function removeByNames(list, names)
    if not names then
        for i = #list, 1, -1 do list[i] = nil end
        return
    end
    local lookup = {}
    for _, n in ipairs(ensureList(names)) do lookup[n] = true end
    for i = #list, 1, -1 do
        if list[i].name and lookup[list[i].name] then
            table.remove(list, i)
        end
    end
end

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

ContextMenu.Register(function(builder, entity, entityType, worldPos, hit)
    if targetingDisabled or not hit then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - worldPos)
    local matched = {}

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        local model = resolveModelKey(entity)

        if models[model] then
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
            if IsPedAPlayer(entity) and entity == PlayerPedId() then
                collectOptions(matched, globalSelfPlayer, entity, worldPos, distance)
            elseif IsPedAPlayer(entity) and entity ~= PlayerPedId() then
                collectOptions(matched, globalOtherPlayer, entity, worldPos, distance)
            elseif IsPedAPlayer(entity) then
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
        builder:AddItem(0, option.label or option.name or 'Option', function(ent, coords)
            triggerOption(option, ent, coords or worldPos)
        end, option.icon, style, option.description)
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

---@param v any
---@return vector3?
local function toVec3(v)
    if v == nil then return nil end
    return vector3(v.x + 0.0, v.y + 0.0, v.z + 0.0)
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

local markerSpriteReady = nil
local markerDeadline = 0

---@return boolean useSprite true if the streamed sprite is ready to draw
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

---@param zone table
---@param playerCoords vector3
---@return boolean onScreen, number sx, number sy, number distance
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

---@param zone table
---@return number r, number g, number b, number a
local function markerColor(zone)
    local c = zone.markerColor
    if not c then return 155, 155, 155, 175 end
    return c[1] or c.r or 155, c[2] or c.g or 155, c[3] or c.b or 155, c[4] or c.a or 175
end

local fbDict, fbTexture = 'commonmenu', 'common_medal'

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

---@param nx number normalized screen x (0-1)
---@param ny number normalized screen y (0-1)
---@return table? zone The targeted marker zone, or nil.
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

OxTargetMarkers = {
    draw = OxTarget.drawZoneMarkers,
    getAtScreen = OxTarget.getMarkerAtScreen,
}

for name, fn in pairs(OxTarget) do
    exports(name, fn)
end
