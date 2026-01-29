--
-- WoodLogsSound
-- This mod plays sounds when you are logging with any vehicles or tools in the game.
-- Sounds play when:
--					logs hit any other logs
--					logs or trees hit the ground
--					trees falling down to ground
-- @author:    	kenny456 (kenny456@seznam.cz)
-- @history:	v1.0 - 2018-12-18 - 
--
WoodLogsSound_register = {};
if SpecializationUtil.specializations["WoodLogsSound"] == nil then
	SpecializationUtil.registerSpecialization("WoodLogsSound", "WoodLogsSound", g_currentModDirectory.."WoodLogsSound.lua");
	WoodLogsSound_register.isLoaded = false; 
end;

function WoodLogsSound_register:loadMap(name)
	if self.firstRun == nil then
		self.firstRun = false;
		print("WoodLogsSound mod loaded")
		for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
			if v ~= nil then
				local allowInsertion = true;
				for i = 1, table.maxn(v.specializations) do
					local vs = v.specializations[i];
					if vs ~= nil and vs == SpecializationUtil.getSpecialization("drivable") then
						local v_name_string = v.name 
						local point_location = string.find(v_name_string, ".", nil, true)
						if point_location ~= nil then
							local _name = string.sub(v_name_string, 1, point_location-1);
							if rawget(SpecializationUtil.specializations, string.format("%s.WoodLogsSound", _name)) ~= nil then
								allowInsertion = false;								
							end;							
						end;
						if allowInsertion then	
							table.insert(v.specializations, SpecializationUtil.getSpecialization("WoodLogsSound"));
							allowInsertion = false;
						end;
					end;
				end;
			end;	
		end;
	end;
end;
function WoodLogsSound_register:deleteMap()
end;
function WoodLogsSound_register:keyEvent(unicode, sym, modifier, isDown)
end;
function WoodLogsSound_register:mouseEvent(posX, posY, isDown, isUp, button)
end;
function WoodLogsSound_register:update(dt)
end;
function WoodLogsSound_register:draw()
end;

addModEventListener(WoodLogsSound_register);
