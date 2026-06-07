local exportHandler = Convert.exportHandler
local convert = Convert.qtargetOptions

local function register(name, fn)
    exports(name, fn)
    exportHandler('qtarget', name, fn)
end

register('AddBoxZone', function(name, center, length, width, options, targetoptions)
    local z = center.z

    if not options.minZ then options.minZ = -100 end
    if not options.maxZ then options.maxZ = 800 end

    if not options.useZ then
        z = z + math.abs(options.maxZ - options.minZ) / 2
        center = vec3(center.x, center.y, z)
    end

    return OxTarget.addBoxZone({
        name = name,
        coords = center,
        size = vec3(width, length, (options.useZ or not options.maxZ) and center.z or math.abs(options.maxZ - options.minZ)),
        rotation = options.heading,
        options = convert(targetoptions),
    })
end)

register('AddPolyZone', function(name, points, options, targetoptions)
    local newPoints = table.create(#points, 0)
    local thickness = math.abs(options.maxZ - options.minZ)

    for i = 1, #points do
        local point = points[i]
        newPoints[i] = vec3(point.x, point.y, options.maxZ - (thickness / 2))
    end

    return OxTarget.addPolyZone({
        name = name,
        points = newPoints,
        thickness = thickness,
        minZ = options.minZ,
        maxZ = options.maxZ,
        options = convert(targetoptions),
    })
end)

register('AddCircleZone', function(name, center, radius, options, targetoptions)
    return OxTarget.addSphereZone({
        name = name,
        coords = center,
        radius = radius,
        options = convert(targetoptions),
    })
end)

register('RemoveZone', function(id)
    OxTarget.removeZone(id)
end)

register('AddTargetBone', function(bones, options)
    if type(bones) ~= 'table' then bones = { bones } end
    options = convert(options)

    for _, v in pairs(options) do
        v.bones = bones
    end

    OxTarget.addGlobalVehicle(options)
end)

register('AddTargetEntity', function(entities, options)
    if type(entities) ~= 'table' then entities = { entities } end
    options = convert(options)

    for i = 1, #entities do
        local entity = entities[i]

        if NetworkGetEntityIsNetworked(entity) then
            OxTarget.addEntity(NetworkGetNetworkIdFromEntity(entity), options)
        else
            OxTarget.addLocalEntity(entity, options)
        end
    end
end)

register('RemoveTargetEntity', function(entities, labels)
    if type(entities) ~= 'table' then entities = { entities } end

    for i = 1, #entities do
        local entity = entities[i]

        if NetworkGetEntityIsNetworked(entity) then
            OxTarget.removeEntity(NetworkGetNetworkIdFromEntity(entity), labels)
        else
            OxTarget.removeLocalEntity(entity, labels)
        end
    end
end)

register('AddTargetModel', function(models, options)
    OxTarget.addModel(models, convert(options))
end)

register('RemoveTargetModel', function(models, labels)
    OxTarget.removeModel(models, labels)
end)

register('Ped', function(options)
    OxTarget.addGlobalPed(convert(options))
end)

register('RemovePed', function(labels)
    OxTarget.removeGlobalPed(labels)
end)

register('Vehicle', function(options)
    OxTarget.addGlobalVehicle(convert(options))
end)

register('RemoveVehicle', function(labels)
    OxTarget.removeGlobalVehicle(labels)
end)

register('Object', function(options)
    OxTarget.addGlobalObject(convert(options))
end)

register('RemoveObject', function(labels)
    OxTarget.removeGlobalObject(labels)
end)

register('Player', function(options)
    local playerType = options.type

    if playerType == 'self' then
        OxTarget.addGlobalSelfPlayer(convert(options))
    elseif playerType == 'other' then
        OxTarget.addGlobalOtherPlayer(convert(options))
    else
        OxTarget.addGlobalPlayer(convert(options))
    end
end)

register('RemovePlayer', function(labels)
    OxTarget.removeGlobalPlayer(labels)
end)

register('Globals', function(options)
    OxTarget.addGlobalOption(convert(options))
end)

register('RemoveGlobals', function(labels)
    OxTarget.removeGlobalOption(labels)
end)
