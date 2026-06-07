Convert = {}

function Convert.ensureList(value)
    if type(value) == 'table' then return value end
    return { value }
end

-- The resource currently calling an ox_target/qtarget export. Captured while
-- still inside the export's synchronous call stack, where GetInvokingResource()
-- is valid. Tagging each option with its owner lets us purge them when that
-- resource stops (otherwise options leak and duplicate on restart).
function Convert.currentOwner()
    return GetInvokingResource() or GetCurrentResourceName()
end

function Convert.tableInsertList(target, options)
    local owner = Convert.currentOwner()
    if options.name or options.label or options.onSelect or options.event or options.serverEvent or options.command or options.export then
        options._owner = owner
        target[#target + 1] = options
        return
    end
    for i = 1, #options do
        if type(options[i]) == 'table' then
            options[i]._owner = owner
        end
        target[#target + 1] = options[i]
    end
end

function Convert.removeByNames(list, names)
    if not names then
        for i = #list, 1, -1 do list[i] = nil end
        return
    end
    local lookup = {}
    for _, n in ipairs(Convert.ensureList(names)) do lookup[n] = true end
    for i = #list, 1, -1 do
        if list[i].name and lookup[list[i].name] then
            table.remove(list, i)
        end
    end
end

function Convert.toVec3(v)
    if v == nil then return nil end
    return vector3(v.x + 0.0, v.y + 0.0, v.z + 0.0)
end

function Convert.exportHandler(prefix, exportName, func)
    AddEventHandler(('__cfx_export_%s_%s'):format(prefix, exportName), function(setCB)
        setCB(func)
    end)
end

function Convert.qtargetOptions(options)
    local distance = options.distance
    options = options.options

    for k, v in pairs(options) do
        if type(k) ~= 'number' then
            table.insert(options, v)
        end
    end

    for id, v in pairs(options) do
        if type(id) ~= 'number' then
            options[id] = nil
            goto continue
        end

        v.onSelect = v.action
        v.distance = v.distance or distance
        v.name = v.name or v.label
        v.groups = v.job
        v.items = v.item or v.required_item

        if v.event and v.type and v.type ~= 'client' then
            if v.type == 'server' then
                v.serverEvent = v.event
            elseif v.type == 'command' then
                v.command = v.event
            end

            v.event = nil
            v.type = nil
        end

        v.action = nil
        v.job = nil
        v.item = nil
        v.required_item = nil
        v.qtarget = true

        ::continue::
    end

    return options
end
