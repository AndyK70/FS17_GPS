local GPS_directory = g_currentModDirectory;
SpecializationUtil.registerSpecialization("GPS", "GPS", GPS_directory.."GPS.lua")
GPS_Register = {};


function GPS_Register:loadMap(name)
	if self.GPS_register_firstRun == nil then
		self.GPS_register_firstRun = false;
		
		local xmlfile = loadXMLFile("modDesc.xml", GPS_directory.."modDesc.xml");
		if xmlfile then
			local GPSversion = getXMLString(xmlfile, "modDesc.version");
			xmlfile = nil;
		end;
		
		if GPSversion then
			modVersion = GPSversion;
		else
			modVersion = "0.00.000";
		end;
		if self.name then
			modName = self.name;
		else
			modName = "GPS";
		end;
		print("--- loading "..modName.." V"..modVersion.." --- (by upsidedown, extended by AndyK70)")
		meMyselfAndI = nil;
		for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
			if v ~= nil then
				local allowInsertion = true;
				for i = 1, table.maxn(v.specializations) do
					local vs = v.specializations[i];
					if vs ~= nil and vs == SpecializationUtil.getSpecialization("steerable") then--
						local v_name_string = v.name 
						local point_location = string.find(v_name_string, ".", nil, true)
						if point_location ~= nil then
							local _name = string.sub(v_name_string, 1, point_location-1);
							if rawget(SpecializationUtil.specializations, string.format("%s.GPS", _name)) ~= nil then
								allowInsertion = false;								
							end;
						end;
						if allowInsertion then	
							table.insert(v.specializations, SpecializationUtil.getSpecialization("GPS"));
						end;
						
						vs.turnOn = g_i18n:getText("turnOn");
						vs.turnOff = g_i18n:getText("turnOff");
						vs.GPS_InfoMode = g_i18n:getText("GPS_InfoMode");
						vs.GPS_NAME = g_i18n:getText("GPS_NAME");
						vs.GPS_userInput = g_i18n:getText("GPS_userInput");
						
						vs.WidthPlus = g_i18n:getText("WidthPlus");
						vs.WidthMinus = g_i18n:getText("WidthMinus");
						vs.AutoWidth = g_i18n:getText("AutoWidth");
						vs.OffsetLeft = g_i18n:getText("OffsetLeft");
						vs.OffsetRight = g_i18n:getText("OffsetRight");
						vs.OffsetZero = g_i18n:getText("OffsetZero");
						vs.InvertOffset = g_i18n:getText("InvertOffset");
						vs.OffsetAutoInvert = g_i18n:getText("OffsetAutoInvert");
						vs.ShiftParallelLeft = g_i18n:getText("ShiftParallelLeft");
						vs.ShiftParallelRight = g_i18n:getText("ShiftParallelRight");
						vs.Degree90 = g_i18n:getText("Degree90");
						vs.RotateRight = g_i18n:getText("RotateRight");
						vs.RotateLeft = g_i18n:getText("RotateLeft");
						vs.GPS_lineMode = g_i18n:getText("GPS_lineMode");
						vs.GPS_wheelMode = g_i18n:getText("GPS_wheelMode");
						vs.GPS_endFieldMode = g_i18n:getText("GPS_endFieldMode");
						vs.TurnLeft = g_i18n:getText("TurnLeft");
						vs.TurnRight = g_i18n:getText("TurnRight");
						vs.AutoStopDistPlus = g_i18n:getText("AutoStopDistPlus");
						vs.AutoStopDistMinus = g_i18n:getText("AutoStopDistMinus");
						vs.MinFreeLanesPlus = g_i18n:getText("MinFreeLanesPlus");
						vs.MinFreeLanesMinus = g_i18n:getText("MinFreeLanesMinus");
						vs.Initiate = g_i18n:getText("Initiate");
						vs.NearestSteerable = g_i18n:getText("NearestSteerable");
						vs.SteeringOnOff = g_i18n:getText("SteeringOnOff");
						vs.StorePlus = g_i18n:getText("StorePlus");
						vs.StoreMinus = g_i18n:getText("StoreMinus");
						vs.Load = g_i18n:getText("Load");
						vs.Save = g_i18n:getText("Save");
						vs.Delete = g_i18n:getText("Delete");
					end;
				end;
			end;	
		end;		
	end;
end;

function GPS_Register:deleteMap()
  
end;

function GPS_Register:keyEvent(unicode, sym, modifier, isDown)

end;

function GPS_Register:mouseEvent(posX, posY, isDown, isUp, button)

end;

function GPS_Register:update(dt)
	
end;

function GPS_Register:draw()
  
end;

addModEventListener(GPS_Register);