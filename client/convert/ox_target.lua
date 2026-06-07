local exportHandler = Convert.exportHandler

local api = {
    addGlobalPlayer = OxTarget.addGlobalPlayer,
    addGlobalSelfPlayer = OxTarget.addGlobalSelfPlayer,
    addGlobalOtherPlayer = OxTarget.addGlobalOtherPlayer,
    addGlobalPed = OxTarget.addGlobalPed,
    addGlobalVehicle = OxTarget.addGlobalVehicle,
    addGlobalObject = OxTarget.addGlobalObject,
    addGlobalOption = OxTarget.addGlobalOption,
    removeGlobalPlayer = OxTarget.removeGlobalPlayer,
    removeGlobalSelfPlayer = OxTarget.removeGlobalSelfPlayer,
    removeGlobalOtherPlayer = OxTarget.removeGlobalOtherPlayer,
    removeGlobalPed = OxTarget.removeGlobalPed,
    removeGlobalVehicle = OxTarget.removeGlobalVehicle,
    removeGlobalObject = OxTarget.removeGlobalObject,
    removeGlobalOption = OxTarget.removeGlobalOption,
    addModel = OxTarget.addModel,
    removeModel = OxTarget.removeModel,
    addEntity = OxTarget.addEntity,
    removeEntity = OxTarget.removeEntity,
    addLocalEntity = OxTarget.addLocalEntity,
    removeLocalEntity = OxTarget.removeLocalEntity,
    addSphereZone = OxTarget.addSphereZone,
    addBoxZone = OxTarget.addBoxZone,
    addPolyZone = OxTarget.addPolyZone,
    removeZone = OxTarget.removeZone,
    disableTargeting = OxTarget.disableTargeting,
}

for name, fn in pairs(api) do
    exports(name, fn)
    exportHandler('ox_target', name, fn)
end
