local specName = "woodHarvesterSound";
local className = "WoodHarvesterSound";
local mainFile = "WoodHarvesterSound.lua";
local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"

if WoodHarvesterSound == nil then
    WoodHarvesterSound = {}
end
WoodHarvesterSound.modDirectory = modDirectory

local function initSpecialization(manager)
    if manager.typeName == "vehicle" then
        g_specializationManager:addSpecialization(specName, className, modDirectory .. mainFile, nil)

        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
            if SpecializationUtil.hasSpecialization(WoodHarvester, typeEntry.specializations) then
                g_vehicleTypeManager:addSpecialization(typeName, modName .. "." .. specName)
            end
        end
    end
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, initSpecialization)
