Keys = {}
Keys.__index = Keys

function Keys.Register(controls, name, description, action)
    RegisterKeyMapping(('off-target:%s'):format(name), description, 'keyboard', controls)
    RegisterCommand(('off-target:%s'):format(name), function()
        if action then action() end
    end, false)
    return setmetatable({ controls = controls }, Keys)
end

function Keys.RegisterToggle(controls, name, description, onPress, onRelease)
    RegisterKeyMapping(('+off-target:%s'):format(name), description, 'keyboard', controls)
    RegisterCommand(('+off-target:%s'):format(name), function()
        if onPress then onPress() end
    end, false)
    RegisterCommand(('-off-target:%s'):format(name), function()
        if onRelease then onRelease() end
    end, false)
end
