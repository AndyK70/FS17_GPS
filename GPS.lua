--
-- GPS with steering assistance
--
-- V5.0 upsidedown 16-10-27: conversion to LS17, new graphics, naming of courses removed
-- 
-- V4.1: upsidedown 14-11-16: changed isField()-method with patch from Koper, fixed autodetection for new workAreas variable, added french translations
-- 
-- V4.0 upsidedown 14-11-01: conversion to LS15 
--
-- V3.2.1 upsidedown 14-08-23
-- distance2field bug fixed
-- added GPS_doSideCorrect inputBinding
-- parallel driving mode improved, damping added
--
-- V3.2 upsidedown 14-08-13
-- takes direction from mrVehicles
-- slotName moved to store-save
-- experimental mode for driving parallel to field edge (expert users only, set self.GPSdoSideCorrect=true for testing)
-- minor changes for compatibility with mr-crabSteer for mr-Xerion by bullgore
-- 
-- gotchTOM @ 12-May-2014
-- V3.1.9 Texte erweitert, angepaßt
-- V3.1.6 user input to rename each course (inspired by courseplay!); storePlus/storeMinus in ten steps; GPS:saveCourse(), GPS:deleteCourse(), GPS:loadCourse() added
--		  update current course, if it was changed by another player in MP 	
-- V3.1.5 GPS_shiftParallel fixed
-- V3.1.4 Sounds in GPS_config.xml
-- V3.1.3 diffAnglecos fixed
-- V3.1.2 Sounds added
--
-- V3.1 minor fixes: MR articulated axis, MR 1.2+ compatible, GPSBaseNode entry for vehicles added, "GPS_config.xml"-error on dedicated servers,  HUD files fixed for lower details setting
--
-- V3.0 long list of changes (crab steer, reverse, flexible steering points, field distance, MR compatible)

-- V2.0 MP ready and new features
-- release date 02.06.2013

-- upsideDown 
-- V1.0: 04/2013
--


GPS = {};
--source("dataS/scripts/vehicles/specializations/SteerableSetSpeedLevelEvent.lua");
local GPS_directory = g_currentModDirectory;

source(Utils.getFilename("GPS_Event.lua", GPS_directory));
source(Utils.getFilename("GPS_SaveEvent.lua", GPS_directory));
source(Utils.getFilename("GPS_DeleteEvent.lua", GPS_directory));

function GPS:prerequisitesPresent(specializations)
    --return true;
	return SpecializationUtil.hasSpecialization(steerable, specializations);
end;

function GPS:load(xmlFile)
	
	-- sounds
	-- SEARCH FOR "sample" to find commented out code for sound
	local GPSwarningSoundFile = Utils.getFilename("GPS_warning.wav", g_modsDirectory.."/ZZZ_GPS/");	
    self.GPSwarningSoundId = createSample("GPSwarningSound");
    loadSample(self.GPSwarningSoundId, GPSwarningSoundFile, false);
	self.GPSallowWarningSound = true;
	self.GPSswitchWarningSound = false;
	
	local GPSstartSoundFile = Utils.getFilename("GPS_on.wav", g_modsDirectory.."/ZZZ_GPS/");	
    self.GPSstartSoundId = createSample("GPSonSound");
    loadSample(self.GPSstartSoundId, GPSstartSoundFile, false);
	self.GPSallowStartSound = true;
	
	local GPSstopSoundFile = Utils.getFilename("GPS_off.wav", g_modsDirectory.."/ZZZ_GPS/");	
    self.GPSstopSoundId = createSample("GPSoffSound");
    loadSample(self.GPSstopSoundId, GPSstopSoundFile, false);
	self.GPSallowStopSound = false;
	
	
	-- if Steerable.GPSinserted == nil then
		-- Steerable.updateVehiclePhysics = Utils.overwrittenFunction(
			-- Steerable.updateVehiclePhysics,
			-- GPS.updateVehiclePhysics);
			
		-- Steerable.GPSinserted = true;
		-- print("GPS mod inserted into Steerable Specialization (should happen only once!)")
	-- end
	if Drivable.GPSinserted == nil then
		Drivable.updateVehiclePhysics = Utils.overwrittenFunction(
			Drivable.updateVehiclePhysics,
			GPS.updateVehiclePhysics);
			
		Drivable.GPSinserted = true;
		print("GPS mod inserted into Drivable Specialization (should happen only once!)")
	end
	
	--Drivable.updateVehiclePhysics

	if VehicleCamera.GPSinserted == nil then
		VehicleCamera.mouseEvent = Utils.overwrittenFunction(VehicleCamera.mouseEvent, GPS.newMouseEvent);
		print("GPS mod inserted into Vehicle Camera (should happen only once!)")
		VehicleCamera.GPSinserted = true;
	end;
	
	if GPS.isDedi == nil then
		GPS.isDedi = GPS:checkIsDedi();
	end;
	
	
	self.GPSWidth = 6;
	
	self.GPSfirstrun = true;
	self.lhBeta = 0;
	self.lhAngle = 0;

	self.GPSshowTime = 0;
	
	self.GPSisActiveSteering = false;
	self.GPSclickTimer = 0;
	
	self.GPSshowMode = 1;
	
	self.GPS_LRoffset = 0;
	self.GPS_LRoffset_resetTimer = 0;
	
	self.GPStxt = {};
	self.GPStxt.txt = "";
	self.GPStxt.r = 0.;
	self.GPStxt.g = 0.;
	self.GPStxt.b = 0.;
	self.GPStxt.bold = false;
	
	self.GPStxt.printDistance = 0;
	
	self.GPS_blinkTime  = 0;
	self.GPS_lastActionText = "";
	
	-----here load optional GPS node from xml
	self.GPSangleOffSet = 0;
	
	local nodeIndex = getXMLString(self.xmlFile, "vehicle.GPSBaseNode#index");
	local GPSbaseNode;
	if nodeIndex==nil then
		GPSbaseNode = self.components[1].node;--self.rootNode;
	else
		GPSbaseNode = Utils.indexToObject(self.components, nodeIndex);
	end;
	

	if self.GPSnode == nil then
		self.GPSnode = createTransformGroup("GPS_Node");
		link(GPSbaseNode,self.GPSnode);
	end;
	
	if GPS.Store == nil then
		GPS.Store = {};
	end;
	self.GPS_storeSlot = 1;
	-- name
	self.GPS_slotName = "";
	self.userInputActive = false;
	self.userInputMessage = nil;
	self.GPScurrentGui = nil
	self.GPSinputGui = "emptyGui";
	
	self.GPSbuttonTimer = 0;
	
	local zNodeForward = 0;
	local zNodeReverse = 0;
	
	for k,wheel in pairs(self.wheels) do --search for front axle position (z coordinate only)
		 local positionX, positionY, positionZ = getWorldTranslation(wheel.repr);
		 local _,_,z = worldToLocal(self.rootNode,positionX, positionY, positionZ);
		 zNodeForward = math.max(zNodeForward,z)
		 zNodeReverse = math.min(zNodeReverse,z)		 
	end;
	
	
	
	self.GPSzNodeForward = zNodeForward;
	self.GPSzNodeReverse = zNodeReverse;
	setTranslation(self.GPSnode,0,0,self.GPSzNodeForward+2) --initial setting
	
	
	self.GPSlaneNo =0;
	self.GPSlaneNoOffset = 0;
	
	
	
	self.GPSautoStopKeyTimer = 0;
	self.GPSautoStop = false;
	self.GPSautoStopDistance = 1.0;
	self.GPSautoStopDone = false;	
	
	self.GPSmovingDirection = 1.0;
	self.GPSmovingDirectionCnt = 40;
	
	self.GPSisTurning = false;
	self.GPSturningDirection = 1.0;
	
	self.GPSturningMinFreeLanes = 0;
	self.GPSTurnInsteadOfAutoStop = false;
	self.GPSturnLimit = 1.0; 
	
	self.GPSdirectionPlusMinus = 1.0;
	
	GPS.stopMouse = false;
	
	self.GPSturnOffset = false; 
	self.GPSshowLines = true;
	self.GPSraiseLines = false;
	self.GPScurrentToolTip = "";
		
	if GPS.isDedi then --clean up after V3.0
		--deleteFile()
		local file = g_modsDirectory.."/GPS_config.xml";
		
		if fileExists(file) then
			print("removing ",file," from dedicated server")
			deleteFile(file)
		end;
		
		
	else --no need to load all the graphics into the dedi		
		GPS:prepareHUD();
		GPS.mouse2InputBindingsLastTime = 0;
		GPS.GPSanalogControllerMode = GPS.Config.wheelMode;
		GPS.GPSstartSound = GPS.Config.startSound;
		GPS.GPSstopSound = GPS.Config.stopSound;
		GPS.GPSwarningSound = GPS.Config.warningSound;
	end;
	
	self.GPSsideCorrect = 0;
	self.GPSdoSideCorrect = false; --change this to true if you want to try the parallel driving
end;



function GPS:updateVehiclePhysics(oldFunc, axisForward, axisForwardIsAnalog, axisSide, axisSideIsAnalog, doHandbrake, dt)	
	local offset = 0;
	if self.GPSsteeringOffset ~= nil then
		offset = self.GPSsteeringOffset
	end
	local newAxis = axisSide;
	if offset ~= 0 then
		if GPS.GPSanalogControllerMode then
			newAxis = offset;
		else
			newAxis = axisSide + offset;
		end;
	end;
	
	

	oldFunc(self, axisForward, axisForwardIsAnalog, newAxis, axisSideIsAnalog, doHandbrake, dt);
end;





function GPS:mouseEvent(posX, posY, isDown, isUp, button)
	if self.GPSshowMode < 3 then
	
		for b,Bu in pairs(GPS.GPS_HUDfields[self.GPSshowMode].buttons) do
			InputBinding.actions[InputBinding.GPS_adjustCourseModifier].noReset = false;
		end;
	
		self.GPScurrentToolTip = "";
		local doModifier = false;
		for b,Bu in pairs(GPS.GPS_HUDfields[self.GPSshowMode].buttons) do
			if (posX >= Bu.xCoord[1]) and (posX <= Bu.xCoord[2]) and (posY >= Bu.yCoord[1]) and (posY <= Bu.yCoord[2]) then
				if Bu.toolTip ~= nil then
					self.GPScurrentToolTip = Bu.toolTip;
				end;
				if (isDown and button == Input.MOUSE_BUTTON_LEFT) or (InputBinding.actions[Bu.binding].isMousePressed and not isUp) then
					if not InputBinding.actions[Bu.binding].isMousePressed then
						InputBinding.actions[Bu.binding].isMouseEvent = true;
					end;
					InputBinding.actions[Bu.binding].isMousePressed = true;
					if Bu.modifier then
						doModifier = true;						
					end;
					InputBinding.actions[InputBinding.GPS_adjustCourseModifier].noReset = true;
				else
					if not InputBinding.actions[InputBinding.GPS_adjustCourseModifier].noReset then
						InputBinding.actions[Bu.binding].isMousePressed = false;
						InputBinding.actions[Bu.binding].isMouseEvent = false;
					end;
				end;
			else 
				if not InputBinding.actions[InputBinding.GPS_adjustCourseModifier].noReset then
					InputBinding.actions[Bu.binding].isMousePressed = false;
					InputBinding.actions[Bu.binding].isMouseEvent = false;
				end;
			end;
		end;

		if doModifier then
			InputBinding.actions[InputBinding.GPS_adjustCourseModifier].isMousePressed = true;
		else
			InputBinding.actions[InputBinding.GPS_adjustCourseModifier].isMousePressed = false;
		end;
	end;
end;

function GPS:keyEvent(unicode, sym, modifier, isDown)
	-- name
	--if isDown and self.userInputActive then
		--GPS:keyInput(self, unicode)
	--end
end;

function GPS:updateTick(dt)
	self.GPSclickTimer = self.GPSclickTimer - dt;
	if self.GPSclickTimer < 0 then
		self.GPSclickTimer = 0;
	end
	self.GPS_LRoffset_resetTimer = self.GPS_LRoffset_resetTimer - dt
	if self.GPS_LRoffset_resetTimer < 0 then
		self.GPS_LRoffset_resetTimer = 0;
	end
	
	-- if self.GPSActive then
		-- if self.GPSisActiveSteering then
			-- self.GPStxt.txt = Steerable.GPS_TXT_ACT;
			-- self.GPStxt.r = .0;
			-- self.GPStxt.g = 0.6;
			-- self.GPStxt.b = 0;
			-- self.GPStxt.bold = true;
		-- else
			-- self.GPStxt.txt = Steerable.GPS_TXT_PAS;
			-- self.GPStxt.r = .0;
			-- self.GPStxt.g = 0.;
			-- self.GPStxt.b = 0.8;
			-- self.GPStxt.bold = false;
		-- end
		-- if self.GPSshowMode > 0 then
			-- self.GPStxt.txt = string.format("%2.2f m", self.GPStxt.printDistance)
		-- end
	-- else
		-- self.GPStxt.txt = Steerable.GPS_TXT_OFF;
		-- self.GPStxt.r = .7;
		-- self.GPStxt.g = 0;
		-- self.GPStxt.b = 0;
		-- self.GPStxt.bold = false;
	-- end

	if self.GPS_blinkTime > 0 then
		self.GPS_blinkTime = self.GPS_blinkTime - dt;
	else
		self.GPS_blinkTime = 0;
	end
	
	if self.GPSshowTime > 0 then
		self.GPSshowTime = self.GPSshowTime - dt;
	else
		self.GPSshowTime = 0;
	end
	
	
	
	--if math.abs(self.axisSide/(1+math.abs(Utils.getNoNil(self.steeringOffset,0)))-Utils.getNoNil(self.steeringOffset,0)) > 0.5 then --reset on manual steering
	--print("GPS ",math.abs(InputBinding.getDigitalInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE)) + math.abs(InputBinding.getAnalogInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE)))
	
	--change to read real input, too many weird steering scripts by upsidedown out there ;)
	if math.abs(InputBinding.getDigitalInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE)) + math.abs(InputBinding.getAnalogInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE)) > 0.5 then
		self.GPSisActiveSteering = false;	
	end
	
	--print(self.name,"  ",self.steeringEnabled)
	if self.steeringEnabled then --test for potential cp-problem
		if GPS.GPSanalogControllerMode then
			self.axisSide = Utils.getNoNil(self.GPSsteeringOffset,0);
		else
			self.axisSide = self.axisSide + Utils.getNoNil(self.GPSsteeringOffset,0); --MP fix. Thats all folks ;-)
		end;
		if self.GPSActive and self.GPSisActiveSteering then
			self.axisSideIsAnalog = true;
		end -- end MP fix. It's all piggybacked on Steerable, no extra network traffic :-)
		-- if not self.isServer then --improve MP sync
			-- self.raiseDirtyFlags(self, self.drivableGroundFlag)
		-- end;
		
	end;
	
end;

function GPS:update(dt)
	--if not self.isClient then --dont bother the dedi
	if GPS.isDedi then --dont bother the dedi
		return
	end;
	
	if true then --prep some flags for HUD
		self.GPS_HUD_AutoLeft = self.GPSautoStop and self.GPSTurnInsteadOfAutoStop and (self.GPSturningDirection > 0);
		self.GPS_HUD_AutoRight = self.GPSautoStop and self.GPSTurnInsteadOfAutoStop and (self.GPSturningDirection < 0);

		self.GPS_HUD_distanceStr = "--  ";		
		if self.GPSdistance2FieldBorder ~= nil then
			if self.GPSautoStop and self.GPSTurnInsteadOfAutoStop then
				self.GPS_HUD_distanceStr = string.format("%2.1f",self.GPSdistance2FieldBorder - self.GPSautoStopDistance);
			else
				self.GPS_HUD_distanceStr = string.format("%2.1f",self.GPSdistance2FieldBorder);
			end;
		end;

		self.GPS_HUD_OffsetStr = "0 ";
		if self.GPS_LRoffset ~= 0 then
			if self.GPS_LRoffset > 0 then
				self.GPS_HUD_OffsetStr = string.format("+%2.1f",self.GPS_LRoffset);
			else
				self.GPS_HUD_OffsetStr = string.format("%2.1f",self.GPS_LRoffset);
			end;
		end;
		
		--GPS_HUD_rowStr
		self.GPS_HUD_rowStr = " 0";
		local row = self.GPSlaneNo - self.GPSlaneNoOffset;
		if row > 0 then
			self.GPS_HUD_rowStr = string.format("+%d",row);
		else		
			self.GPS_HUD_rowStr = string.format("%d",row);
		end;
		
		self.GPSanalogControllerMode = GPS.GPSanalogControllerMode; --copy for comp. with HUD
		
		self.GPS_HUD_Slot_exists = false;
		if GPS.Store~= nil then
			if GPS.Store[self.GPS_storeSlot] ~= nil then
				if GPS.Store[self.GPS_storeSlot].lhdX0 ~= nil then
					self.GPS_HUD_Slot_exists = true;
				end;
			end;
		end;
		
						
	end;

	GPS:transferMouse2InputBinding();

	local needPushEvent = false;
	local isCourseAdjust = InputBinding.isPressed(InputBinding.GPS_adjustCourseModifier);
		
	if self:getIsActiveForInput(false) then
		if InputBinding.hasEvent(InputBinding.GPS_OnOff) then
			self.GPSActive = not self.GPSActive;
			
			
			if self.hirableToolsHUD ~= nil then --resolve inputbinding conflict with hireable tools
				if InputBinding.hasEvent(InputBinding.HELFERTOOLS_HUD) then
					local state = self.hirableToolsHUD.isActive;
					state = not state;
					if not self.hirableToolsAllowed then
						state = false;
					end;
					InputBinding.setShowMouseCursor(state);
					self.hirableToolsHUD.isActive = state;
				end;

			end;
			-- name -> update self.GPS_slotName
			if self.GPSActive then
				if GPS.Store[self.GPS_storeSlot] ~= nil and GPS.Store[self.GPS_storeSlot].GPS_slotName ~= nil then
					self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName;
				end;
			end;
			
			
		end;
		
		if InputBinding.hasEvent(InputBinding.GPS_doSideCorrect) then --dev code
			self.GPSdoSideCorrect = not self.GPSdoSideCorrect;
			print("GPS doSideCorrect = "..tostring(self.GPSdoSideCorrect))
		end;
		
		if InputBinding.hasEvent(InputBinding.GPS_InfoMode) then
			self.GPSshowMode = self.GPSshowMode + 1;
			if self.GPSshowMode > 3 then
				self.GPSshowMode = 1;
			end;
		end
		
		if InputBinding.hasEvent(InputBinding.GPS_lineMode) then
			
			if not self.GPSshowLines then
				self.GPSshowLines = true;
				self.GPSraiseLines = false;
			else
				if not self.GPSraiseLines then
					self.GPSshowLines = true;
					self.GPSraiseLines = true;
				else
					self.GPSshowLines = false;
					self.GPSraiseLines = false;
				end;
			end;
		end;
		
		if InputBinding.hasEvent(InputBinding.GPS_wheelMode) then
			GPS.GPSanalogControllerMode = not GPS.GPSanalogControllerMode;
		end;		
			
		if self.GPSActive then
			-- update the name of the current course, if it was changed by another user in MP
			if GPS.GPSchangedSlot ~= nil then
				if self.GPS_storeSlot == GPS.GPSchangedSlot then	
					if GPS.Store[self.GPS_storeSlot] ~= nil then -- slot was saved
						-- GPS:loadCourse(self);
						self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName
					else -- slot was deleted
						if self.GPS_slotName ~= "" then
							self.GPS_slotName = "";
						end;
					end;
				end;	
				GPS.GPSchangedSlot = nil;
			end;
			
			if not self.userInputActive then
				if isCourseAdjust then
					if (InputBinding.isPressed(InputBinding.GPS_OffsetLeft) and InputBinding.isPressed(InputBinding.GPS_OffsetRight)) or InputBinding.hasEvent(InputBinding.GPS_OffsetZero) then
						self.GPS_LRoffset = 0;
						self.GPS_LRoffset_resetTimer = 800;
						needPushEvent = true;
					elseif self.GPS_LRoffset_resetTimer == 0 then
						if InputBinding.isPressed(InputBinding.GPS_OffsetRight) then
							self.GPS_LRoffset = self.GPS_LRoffset + .0008*dt;				
							self.GPSshowTime = 800;
							needPushEvent = true;
						end;
						
						if InputBinding.isPressed(InputBinding.GPS_OffsetLeft) then
							self.GPS_LRoffset = self.GPS_LRoffset - .0008*dt;				
							self.GPSshowTime = 800;
							needPushEvent = true;
						end;		
					end
					if InputBinding.isPressed(InputBinding.GPS_WidthPlus) then
								self.GPSWidth = self.GPSWidth + .00025*dt*(self.GPSWidth+1);
						if self.GPSWidth > 50 then
							self.GPSWidth = 50;
						end;
						self.GPSshowTime = 800;
						self.GPSclickTimer = 2000;
						needPushEvent = true;
					end;
					
					if InputBinding.isPressed(InputBinding.GPS_WidthMinus) then		
						self.GPSWidth = self.GPSWidth - .00025*dt*(self.GPSWidth+1);
						if self.GPSWidth < 0 then
							self.GPSWidth = 0;
						end;
						self.GPSshowTime = 800;
						self.GPSclickTimer = 2000;
						needPushEvent = true;
					end;
					
					--parallel shift calc
					
					if self.GPS_LRoffset > self.GPSWidth/2 then
						self.GPS_LRoffset = self.GPSWidth/2;
					end;
					if self.GPS_LRoffset < -self.GPSWidth/2 then
						self.GPS_LRoffset = -self.GPSWidth/2;
					end;
					
					if InputBinding.isPressed(InputBinding.GPS_shiftParallelRight) then 
						local ppx,ppy,ppz = getWorldTranslation(self.GPSnode);
						local xxx,yyy,zzz = worldToLocal(self.GPSnode,ppx+dt*0.001*self.lhdZ0,ppy,ppz+dt*0.001*self.lhdX0);
						local lr = self.GPSdirectionPlusMinus;
						-- local lr = 1.0;
						-- if xxx > 0 then
							-- lr = -1.0;
						-- end;
						local lhdX0 = self.lhdX0
						local lhdZ0 = self.lhdZ0
						local diff = math.abs(lhdX0) - math.abs(lhdZ0)
						if diff < 0.00001 then
							lr = self.GPSdirectionPlusMinus*(-1);
							if lhdZ0 ~= 0 then
								lhdX0 = 0;
							else
								lhdX0 = 1;
							end;	
						end;
						self.lhX0 = self.lhX0 + lr*dt*0.001*lhdZ0;
						self.lhZ0 = self.lhZ0 + lr*dt*0.001*lhdX0;
						self.GPSshowTime = 800;
						self.GPSclickTimer = 2000;
						needPushEvent = true;
					end;
				
					if InputBinding.isPressed(InputBinding.GPS_shiftParallelLeft) then 
						local ppx,ppy,ppz = getWorldTranslation(self.GPSnode);
						local xxx,yyy,zzz = worldToLocal(self.GPSnode,ppx+dt*0.001*self.lhdZ0,ppy,ppz+dt*0.001*self.lhdX0);
						local lr = self.GPSdirectionPlusMinus;
						-- local lr = 1.0;
						-- if xxx > 0 then
							-- lr = -1.0;
						-- end;
						local lhdX0 = self.lhdX0
						local lhdZ0 = self.lhdZ0
						local diff = math.abs(lhdX0) - math.abs(lhdZ0)
						if diff < 0.00001 then
							lr = self.GPSdirectionPlusMinus*(-1);
							if lhdZ0 ~= 0 then
								lhdX0 = 0;
							else
								lhdX0 = 1;
							end;	
						end;
						self.lhX0 = self.lhX0 - lr*dt*0.001*lhdZ0;
						self.lhZ0 = self.lhZ0 - lr*dt*0.001*lhdX0;
						self.GPSshowTime = 800;
						self.GPSclickTimer = 2000;
						needPushEvent = true;
					end;
							
					if InputBinding.hasEvent(InputBinding.GPS_90Grad) then 
						local swap = self.lhdX0;
						self.lhdX0 = -self.lhdZ0;
						self.lhdZ0 = swap;
						needPushEvent = true;
						self.GPSclickTimer = 2000;
						--print("90")
					end;	
					
					if InputBinding.hasEvent(InputBinding.GPS_InvertOffset_V3) then
						self.GPS_LRoffset = -self.GPS_LRoffset;
						self.GPSshowTime = 800;
						needPushEvent = true;
					end
					
				end;

				if InputBinding.isPressed(InputBinding.GPS_MouseModifier) and self.GPSshowMode == 2 then 
					if not GPS.stopMouse then
						GPS.stopMouse = true;
						InputBinding.setShowMouseCursor(true);
					end;
				else
					if GPS.stopMouse then
						GPS.stopMouse = false;
						InputBinding.setShowMouseCursor(false);
						self.GPScurrentToolTip = "";
						self.GPSbuttonTimer = 0;
					end;
				end;
				
				if InputBinding.hasEvent(InputBinding.GPS_SteeringOnOff) then
					self.GPSisActiveSteering = not self.GPSisActiveSteering;
				end
				
				
				if InputBinding.hasEvent(InputBinding.GPS_resetRowNo) then
					self.GPSlaneNoOffset = self.GPSlaneNo;
					needPushEvent = true;
				end;
				
				-- name -> userInput
				--if InputBinding.hasEvent(InputBinding.GPS_userInput) then
				--if InputBinding.hasEvent(InputBinding.GPS_Save) then
					--self.userInputActive = true;
					--self.userInputMessage = string.format(Steerable.GPS_NAME, self.typeDesc) .. ": ";
				--end;
				
				if InputBinding.hasEvent(InputBinding.GPS_storePlus) then
					self.GPS_storeSlot = self.GPS_storeSlot + 1;
					self.GPSbuttonTimer = self.time + 1000;
					-- name -> update self.GPS_slotName
					if GPS.Store[self.GPS_storeSlot] ~= nil and GPS.Store[self.GPS_storeSlot].GPS_slotName ~= nil then
						self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName
					else
						self.GPS_slotName = "";
					end;
					self.GPSshowTime = 800;
					needPushEvent = true;
				end;
				if InputBinding.isPressed(InputBinding.GPS_storePlus) then
					if self.GPSbuttonTimer < self.time then
						self.GPSbuttonTimer = self.time + 1000;
						self.GPS_storeSlot = self.GPS_storeSlot + 10;
						-- name -> update self.GPS_slotName
						if GPS.Store[self.GPS_storeSlot] ~= nil and GPS.Store[self.GPS_storeSlot].GPS_slotName ~= nil then
							self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName
						else
							self.GPS_slotName = "";
						end;
						self.GPSshowTime = 800;
						needPushEvent = true;
					end;
				end;
				
				if InputBinding.hasEvent(InputBinding.GPS_storeMinus) then
					self.GPS_storeSlot = math.max(self.GPS_storeSlot - 1, 1);
					self.GPSbuttonTimer = self.time + 1000;
					-- name -> update self.GPS_slotName
					if GPS.Store[self.GPS_storeSlot] ~= nil and GPS.Store[self.GPS_storeSlot].GPS_slotName ~= nil then
						self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName
					else
						self.GPS_slotName = "";
					end;
					self.GPSshowTime = 800;
					needPushEvent = true;
				end;
				if InputBinding.isPressed(InputBinding.GPS_storeMinus) then
					if self.GPSbuttonTimer < self.time then
						self.GPSbuttonTimer = self.time + 1000;
						self.GPS_storeSlot = math.max(self.GPS_storeSlot - 10, 1);
						-- name -> update self.GPS_slotName
						if GPS.Store[self.GPS_storeSlot] ~= nil and GPS.Store[self.GPS_storeSlot].GPS_slotName ~= nil then
							self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName
						else
							self.GPS_slotName = "";
						end;
						self.GPSshowTime = 800;
						needPushEvent = true;
					end;
				end;
				
				if InputBinding.hasEvent(InputBinding.GPS_Delete) then
					GPS:deleteCourse(self, self.GPS_storeSlot);
				end;
								
				if InputBinding.hasEvent(InputBinding.GPS_Save) then
					GPS:saveCourse(self, self.GPS_storeSlot);
				end

				if InputBinding.hasEvent(InputBinding.GPS_Load) then
					GPS:loadCourse(self);
				end
				
				
				if InputBinding.hasEvent(InputBinding.GPS_NearestSteerable) then 
					local nVehicles = table.getn(g_currentMission.steerables);
					local nearestFoundIndex = 0
					local nearestFoundDistance = 100000;
					if nVehicles > 0 then
						local self_x,_,self_z = getWorldTranslation(self.rootNode)
						for i=1,nVehicles do
							local oVehicle = g_currentMission.steerables[i];
							local near_x,_,near_z = getWorldTranslation(oVehicle.rootNode)
							local nearestDistance = Utils.vector2Length(near_x-self_x,near_z-self_z);
							if oVehicle ~= self then
								if nearestDistance < nearestFoundDistance then
									nearestFoundDistance = nearestDistance;
									nearestFoundIndex = i;
								end
							end
						end				
						--here we have nearestFoundIndex, nearestFoundDistance
						if nearestFoundIndex ~= 0 then
							nearestVehicle = g_currentMission.steerables[nearestFoundIndex]
							if nearestVehicle.lhdX0 ~= nil then
								self.lhdX0 = nearestVehicle.lhdX0
								self.lhdZ0 = nearestVehicle.lhdZ0
								self.lhX0 = nearestVehicle.lhX0
								self.lhZ0 = nearestVehicle.lhZ0
								self.GPSWidth = nearestVehicle.GPSWidth
								self.GPS_LRoffset = nearestVehicle.GPS_LRoffset
								self.GPS_blinkTime = 2500;
								self.GPS_lastActionText = Steerable.GPS_TXT_LOAD
								needPushEvent = true;
							end
						end
						
					end
				end
				
				
				if InputBinding.hasEvent(InputBinding.GPS_AutoWidth) then 
					local xmin = 0;
					local xmax = 0;
					xmin,xmax = GPS.xMinMaxAI(self,self,xmin,xmax);
					--xmin,xmax = GPS.xMinMaxAreas(self,self.cuttingAreas,xmin,xmax);
					xmin,xmax = GPS.xMinMaxAreas(self,self.workAreas,xmin,xmax);
					--xmin,xmax = GPS.xMinMaxAreas(self,self.mowerCutAreas,xmin,xmax);
					--xmin,xmax = GPS.xMinMaxAreas(self,self.fruitPreparerAreas,xmin,xmax);
					
					for nIndex,oImplement in pairs(self.attachedImplements) do --parse implements
						if oImplement ~= nil and oImplement.object ~= nil then
							xmin,xmax = GPS.xMinMaxAI(self,oImplement.object,xmin,xmax);
							--xmin,xmax = GPS.xMinMaxAreas(self,oImplement.object.cuttingAreas,xmin,xmax);
							xmin,xmax = GPS.xMinMaxAreas(self,oImplement.object.workAreas,xmin,xmax);
							--xmin,xmax = GPS.xMinMaxAreas(self,oImplement.object.mowerCutAreas,xmin,xmax);
							--xmin,xmax = GPS.xMinMaxAreas(self,oImplement.object.fruitPreparerAreas,xmin,xmax);
							for nIndex2,oImplement2 in pairs(oImplement.object.attachedImplements) do --parse 2nd line implements
								xmin,xmax = GPS.xMinMaxAI(self,oImplement2.object,xmin,xmax);
								--xmin,xmax = GPS.xMinMaxAreas(self,oImplement2.object.cuttingAreas,xmin,xmax);
								xmin,xmax = GPS.xMinMaxAreas(self,oImplement2.object.workAreas,xmin,xmax);
								--xmin,xmax = GPS.xMinMaxAreas(self,oImplement2.object.mowerCutAreas,xmin,xmax);
								--xmin,xmax = GPS.xMinMaxAreas(self,oImplement2.object.fruitPreparerAreas,xmin,xmax);
							end
						end
					end

					local width = math.abs(xmax-xmin);
					if width > .1 then
						self.GPSWidth = width;
						self.GPS_LRoffset = (xmin+xmax)/2;
						if math.abs(self.GPS_LRoffset) < 0.1 then
							self.GPS_LRoffset = 0;
						end
						
						local offsetFactor = 1.0;
						if self.GPSturnOffset then
							offsetFactor = self.GPSdirectionPlusMinus;
						end;
						self.GPS_LRoffset = self.GPS_LRoffset*offsetFactor;
						
						self.GPSshowTime = 800;
						needPushEvent = true;
					end				
				end
				
				
				
				if InputBinding.hasEvent(InputBinding.GPS_OffsetAutoInvert) then
					self.GPSturnOffset = not self.GPSturnOffset;
					needPushEvent = true;
				end;
				
				--
				-- if InputBinding.isPressed(InputBinding.GPS_turnLimitPlus) then 
					-- self.GPSturnLimit = self.GPSturnLimit + dt*0.001*.2;
					-- needPushEvent = true;
				-- end;
				
				-- if InputBinding.isPressed(InputBinding.GPS_turnLimitMinus) then 
					-- self.GPSturnLimit = self.GPSturnLimit - dt*0.001*.2;
					-- needPushEvent = true;
				-- end;
				
				-- self.GPSturnLimit = Utils.clamp(self.GPSturnLimit,.2,1.0);
				
				
				
				if isCourseAdjust then --use up/down for course manipulation
					if InputBinding.isPressed(InputBinding.GPS_turnLeft) then 
						local refNode = self.GPSnode;
						local rx,_,rz = getWorldTranslation(refNode);
						self.lhX0 = rx + self.GPSWidth*self.lhdZ0*self.lhBeta;
						self.lhZ0 = rz - self.GPSWidth*self.lhdX0*self.lhBeta;
					
					
						local alpha = math.rad(45)*0.0002*dt;
						self.lhdX0 = math.cos(alpha)*self.lhdX0 - math.sin(alpha)*self.lhdZ0;
						self.lhdZ0 = math.cos(alpha)*self.lhdZ0 + math.sin(alpha)*self.lhdX0;			
						self.GPSclickTimer = 2000;
						needPushEvent = true;
					end;

					if InputBinding.isPressed(InputBinding.GPS_turnRight) then 
						local refNode = self.GPSnode;
						local rx,_,rz = getWorldTranslation(refNode);
						self.lhX0 = rx + self.GPSWidth*self.lhdZ0*self.lhBeta;
						self.lhZ0 = rz - self.GPSWidth*self.lhdX0*self.lhBeta;
						local alpha = math.rad(45)*0.0002*dt;
						self.lhdX0 = math.cos(alpha)*self.lhdX0 + math.sin(alpha)*self.lhdZ0;
						self.lhdZ0 = math.cos(alpha)*self.lhdZ0 - math.sin(alpha)*self.lhdX0;			
						self.GPSclickTimer = 2000;
						needPushEvent = true;
					end;
				else --use up/down for field distance +/- on/off
					if self.GPSautoStopKeyTimer == 0 then
						if InputBinding.isPressed(InputBinding.GPS_turnLeft) and InputBinding.isPressed(InputBinding.GPS_turnRight) then
							self.GPSautoStopKeyTimer = 800;
							self.GPSautoStop = not self.GPSautoStop;
							--print("autostop: ",self.GPSautoStop)
						elseif InputBinding.isPressed(InputBinding.GPS_turnRight) then
							self.GPSautoStopDistance = math.max(self.GPSautoStopDistance - 0.01*dt,1.00);
							--print("autostop distance: ",self.GPSautoStopDistance)
						elseif InputBinding.isPressed(InputBinding.GPS_turnLeft) then
							self.GPSautoStopDistance = math.min(self.GPSautoStopDistance + 0.01*dt,80);
							--print("autostop distance: ",self.GPSautoStopDistance)
						end;			
					else
						self.GPSautoStopKeyTimer = math.max(self.GPSautoStopKeyTimer - dt,0);
					end;
					
					if InputBinding.hasEvent(InputBinding.GPS_endFieldMode) then
						--self.GPSautoStop   --self.GPSTurnInsteadOfAutoStop
						if self.GPSTurnInsteadOfAutoStop then
							self.GPSTurnInsteadOfAutoStop = false;
							self.GPSautoStop = false;
						else
							if self.GPSautoStop then
								self.GPSTurnInsteadOfAutoStop = true;
								self.GPSautoStop = true;
							else
								self.GPSTurnInsteadOfAutoStop = false;
								self.GPSautoStop = true;
							end
						end;
					end;
					
					--
					if InputBinding.hasEvent(InputBinding.GPS_minFreeLanesPlus) then
						self.GPSturningMinFreeLanes = self.GPSturningMinFreeLanes + 1;
						needPushEvent = true;
					end;

					if InputBinding.hasEvent(InputBinding.GPS_minFreeLanesMinus) then
						self.GPSturningMinFreeLanes = self.GPSturningMinFreeLanes - 1;
						self.GPSturningMinFreeLanes = math.max(self.GPSturningMinFreeLanes,0);					
						needPushEvent = true;
					end;
					
					
				end;
			end;
---------------------------------------------------------------------------------------------------------			
			local px,py,pz = getWorldTranslation(self.GPSnode);
			local x,y,z = localDirectionToWorld(self.GPSnode, 0, 0, 1);
			local length = Utils.vector2Length(x,z);
			local dX = x/length;
			local dZ = z/length;
			
			if (InputBinding.hasEvent(InputBinding.GPS_Init) and not self.userInputActive) or self.GPSfirstrun then
				needPushEvent = true;
				self.GPSclickTimer = 3500;
				--if self.GPSangleModeLS13 then --snap to terrain directions
					local snapAngle = self:getDirectionSnapAngle();
					snapAngle = math.max(snapAngle, math.pi/(g_currentMission.terrainDetailAngleMaxValue+1));

					local angleRad = Utils.getYRotationFromDirection(x, z)
					angleRad = math.floor(angleRad / snapAngle + 0.5) * snapAngle;

					local snapX, snapZ = Utils.getDirectionFromYRotation(angleRad);	
					
					self.lhdX0 = snapX
					self.lhdZ0 = snapZ
				-- else -- use precisely the current orientation of the tractor. LS11 mode for non-lego field layouts
					-- self.lhdX0 = dX;
					-- self.lhdZ0 = dZ;
				-- end
				local offFac = 1.0;
				local lh = Utils.getNoNil(self.GPSdirectionPlusMinus,1.0);
				if self.GPSturnOffset then
					offFac = lh;
				end;
				
				self.lhX0 = px + offFac*lh*self.GPS_LRoffset*self.lhdZ0;
				self.lhZ0 = pz - offFac*lh*self.GPS_LRoffset*self.lhdX0;	
				
				self.GPSfirstrun = false;
			end;
			
			local acosValue = dX*self.lhdX0 + dZ*self.lhdZ0;
			acosValue = math.min(acosValue,1);
			acosValue = math.max(acosValue,-1);
			local diffAnglecos = math.deg(math.acos(acosValue));  -- acosValue only between 1 and -1 allowed for math.acos
					
			local signDiffAngle = math.deg(math.asin(dX*self.lhdZ0 - dZ*self.lhdX0));
			
			local beta = 0;
					
			beta = self.lhdX0 *(pz - self.lhZ0) - self.lhdZ0 *(px - self.lhX0)
			beta = beta / self.GPSWidth
			self.GPSlaneNo = math.floor(beta+.5); -- - self.GPSlaneNoOffset;
			--print(self.GPSlaneNo - self.GPSlaneNoOffset)

			beta = (beta - math.floor(beta+.5)); 
			
			self.lhBeta = beta;
			self.lhAngle = signDiffAngle; --self.lhAngle = diffAnglecos;
			
			local lhDirectionPlusMinus = 1;
			if diffAnglecos > 90  then
				lhDirectionPlusMinus = -1;
			end;
			self.GPSdirectionPlusMinus = lhDirectionPlusMinus;
			
			-------------------------------------------------------
			-- if false then -- experimental courseplay coupling
				-- local distance_nearest = 9999999999;
				-- local k_nearest = nil;
				-- for k,wp in pairs(self.Waypoints) do
					-- if wp.cx~= nil then
						-- local distance = math.sqrt((wp.cx-px)^2+(wp.cz-pz)^2);
						
						-- if distance < distance_nearest then
							-- distance_nearest = distance;
							-- k_nearest = k;
						-- end;						
					-- end;
				-- end;
				
				-- local k_max = table.getn(self.Waypoints);
				-- if k_nearest == k_max then
					-- k_nearest = k_max -1;
				-- end;
				-- self.lhX0 = self.Waypoints[k_nearest].cx
				-- self.lhZ0 = self.Waypoints[k_nearest].cz
				-- self.lhdX0 = self.Waypoints[k_nearest+1].cx - self.Waypoints[k_nearest].cx
				-- self.lhdZ0 = self.Waypoints[k_nearest+1].cz - self.Waypoints[k_nearest].cz
				-- local length = Utils.vector2Length(self.lhdX0,self.lhdZ0);
				-- self.lhdX0 = self.lhdX0/length;
				-- self.lhdZ0 = self.lhdZ0/length;
				-- print(k_nearest," ",self.lhdX0," ",self.lhdZ0)
			-- end;
			--------------------------end courseplay coupling-----------------
						
			if self.lastMovedDistance ~= 0  then
			
				if self.articulatedAxis == nil or true then
					if self.movingDirection > 0 and (self.lastSpeedReal > 0.00005) then
						self.GPSmovingDirectionCnt = self.GPSmovingDirectionCnt + 1;					
					elseif self.movingDirection < 0 and (self.lastSpeedReal > 0.00005) then
						self.GPSmovingDirectionCnt = self.GPSmovingDirectionCnt - 1;
					end;

					
					self.GPSmovingDirectionCnt = Utils.clamp(self.GPSmovingDirectionCnt,-4,8);
				end;
				
					if self.GPSmovingDirectionCnt > 0 then
						self.GPSmovingDirection = 1.0;
						setTranslation(self.GPSnode,0,0,self.GPSzNodeForward+2) --put the steering node 2m in front of front axle
					else
						self.GPSmovingDirection = -1.0;
						setTranslation(self.GPSnode,0,0,self.GPSzNodeReverse-3) --put the steering node 3m behind of back axle
					end;
					
	
					if self.GPSmovingDirectionCnt > 0 then
						self.GPSmovingDirection = 1.0;							
					else
						self.GPSmovingDirection = -1.0;							
					end;					
					
					
					if self.GPSmovingDirection > 0 then
						--self.GPSmovingDirection = 1.0;
						setTranslation(self.GPSnode,0,0,self.GPSzNodeForward+2) --put the steering node 2m in front of front axle
					else
						--self.GPSmovingDirection = -1.0;
						setTranslation(self.GPSnode,0,0,self.GPSzNodeReverse-3) --put the steering node 3m behind of back axle
					end;
					
					
				--end;
				
			else
				--print("standstill")
			end
			
			
			if not isCourseAdjust and not self.userInputActive then --double use inputbindings for turn control
				if InputBinding.hasEvent(InputBinding.GPS_shiftParallelRight) then
					if self.GPSturningDirection < 0 then
						self.GPSisTurning = not self.GPSisTurning;
						if self.GPSisTurning then
							self.GPSisTurningStartLane = self.GPSlaneNo;
							self.GPSforceDirectionPlusMinus = -lhDirectionPlusMinus;
						end;
					else
						self.GPSturningDirection = -1.0;
					end;
				end;
				
				if InputBinding.hasEvent(InputBinding.GPS_shiftParallelLeft) then
					if self.GPSturningDirection > 0 then
						self.GPSisTurning = not self.GPSisTurning;
						if self.GPSisTurning then
							self.GPSisTurningStartLane = self.GPSlaneNo;
							self.GPSforceDirectionPlusMinus = -lhDirectionPlusMinus;
						end;
					else
						self.GPSturningDirection = 1.0;
					end;
				end;
			end;
			
			if self.GPSisActiveSteering then --here starts autopilot:			
				local angleLimit = 80;
				
				local refangle = signDiffAngle*lhDirectionPlusMinus*self.movingDirection;
				
				
				local K1 = 15;				
				local K2 = .025;
				
				local offsetFactor = 1.0;
				if self.GPSturnOffset then
					offsetFactor = lhDirectionPlusMinus;
				end;
				
				local angle_soll = K1 * (beta-lhDirectionPlusMinus*offsetFactor*(self.GPS_LRoffset + self.GPSsideCorrect + Utils.getNoNil(self.GPS_externalLRoffset,0))/self.GPSWidth) * self.GPSWidth*lhDirectionPlusMinus + self.GPSangleOffSet;
				angle_soll = Utils.clamp(angle_soll,-angleLimit,angleLimit);
				
				local forceSteer = nil;
				if self.GPSisTurning then
					if self.GPSforceDirectionPlusMinus ~= nil then
						if self.GPSforceDirectionPlusMinus == lhDirectionPlusMinus and math.abs(self.GPSisTurningStartLane - self.GPSlaneNo) > self.GPSturningMinFreeLanes then --we point into correct hemisphere and are not in start lane(+extra free lanes)
							self.GPSforceDirectionPlusMinus = nil;
							self.GPSisTurning = false;
							self.GPSturningDirection = -self.GPSturningDirection;
						elseif self.GPSforceDirectionPlusMinus ~= lhDirectionPlusMinus and math.abs(self.GPSisTurningStartLane - self.GPSlaneNo) > self.GPSturningMinFreeLanes then --we are in a fine lane but still point into wrong hemisphere
							forceSteer = -1.0*self.GPSturningDirection;
							
						else
							angle_soll = 80*self.GPSturningDirection;
						end;
					end;
				else
					-- sounds
					if math.abs(self.GPSsteeringOffset) > 1 and not self.GPSallowWarningSound then
						self.GPSswitchWarningSound = true;
					end;
				end;
				-- sounds
				if self.GPSswitchWarningSound and math.abs(self.GPSsteeringOffset) < .1 then
					self.GPSallowWarningSound = true;
					self.GPSswitchWarningSound = false;
				end;
				
				local steer = K2*(refangle - angle_soll);
				if forceSteer ~= nil then
					steer = forceSteer;
				end;
				
				if self.invertedDrivingDirection==true or self.newInvertedDrivingDirection==true or self.ddIsInverted==true or self.rufaActive==true or self.isReverseDriving then					
					steer = -steer;					
				end;
				
				if self.articulatedAxis ~= nil or self.steeringMode~= nil then						
					if self.lastSpeedReal * 3600 < 0.1  then --change for LS15
						steer = self.GPSsteeringOffset; --just dont steer while standing (nearly) still in an articulated vehicle
					end;					
				end;
				
				if self.GPSisTurning then
					steer = Utils.clamp(steer,-self.GPSturnLimit,self.GPSturnLimit);
				end;
				
				
				
				if true then
					self.GPSsteeringOffset = steer;
				else --damping 
					self.GPSsteeringOffset = 0.85*self.GPSsteeringOffset + 0.15*steer;
				end;
			else
				self.GPSisTurning = false;
				self.GPSsteeringOffset = 0									
			end
			
			local printDistance = beta * self.GPSWidth;
			printDistance = printDistance - self.GPS_LRoffset;
			if math.abs(printDistance) < 0.005 then
				printDistance = 0; --prevent +/- flickering
			end
			
			self.GPStxt.printDistance = printDistance;
			
			
			local x0 = px + self.GPSWidth*self.lhdZ0*(beta);
			local z0 = pz - self.GPSWidth*self.lhdX0*(beta);
			local isField = GPS:isField(x0,z0);
			
			local sideCorrectTarget = 0;
			if self.GPSdoSideCorrect then 
				----------------
				local disA = -1;
				--self.GPSsideCorrect = 0;
				if (isField or GPS:isField(px,pz)) and true then --search right
					local dis = 0;
					local isSearchPointOnField = isField;
					local stepA = .2;
					local stepB = -.025;
					
					while isSearchPointOnField do --search fast forward (1m steps)
						dis = dis + stepA;
						local xx = x0 + dis*lhDirectionPlusMinus*self.lhdZ0;
						local zz = z0 + dis*lhDirectionPlusMinus*self.lhdX0;
						isSearchPointOnField = GPS:isField(xx,zz);						
						if math.abs(dis) > self.GPSWidth*0.5 then
							isSearchPointOnField = false;
							dis = -2000;
							break;
						end;						
					end;
					--print("disA ",tostring(dis))
					while not isSearchPointOnField and dis > -2000 do --then backtrace in small 5cm steps
						dis = dis + stepB;
						local xx = x0 + dis*lhDirectionPlusMinus*self.lhdZ0;
						local zz = z0 + dis*lhDirectionPlusMinus*self.lhdX0;
						isSearchPointOnField = GPS:isField(xx,zz);
						if math.abs(dis) > self.GPSWidth/2 then
							dis = -2000;
							break;
						end;						
					end;
					--print("disB ",tostring(dis))
					
					if dis > -2000 then
						--self.GPSsideCorrect = -self.GPSWidth/2+dis;
						sideCorrectTarget = -self.GPSWidth/2+dis;
						disA = dis;
					else
						--self.GPSsideCorrect = 0;
						sideCorrectTarget = 0;
					end;
					--print("1",dis," ",self.GPSsideCorrect)
				end;
				-----------
				if (isField or GPS:isField(px,pz)) and disA < 0 then --search left
					local dis = 0;
					local isSearchPointOnField = isField;
					local stepA = .2;
					local stepB = -.025;
					
					while isSearchPointOnField do --search fast forward (1m steps)
						dis = dis + stepA;
						local xx = x0 - dis*lhDirectionPlusMinus*self.lhdZ0;
						local zz = z0 - dis*lhDirectionPlusMinus*self.lhdX0;
						isSearchPointOnField = GPS:isField(xx,zz);						
						if math.abs(dis) > self.GPSWidth*0.5 then
							isSearchPointOnField = false;
							dis = -2000;
							break;
						end;						
					end;
					--renderText(0.6,0.3,0.02,"disA2 "..tostring(dis))
					while not isSearchPointOnField and dis > -2000 do --then backtrace in small 5cm steps
						dis = dis + stepB;
						local xx = x0 + dis*lhDirectionPlusMinus*self.lhdZ0;
						local zz = z0 + dis*lhDirectionPlusMinus*self.lhdX0;
						isSearchPointOnField = GPS:isField(xx,zz);	
						if math.abs(dis) > self.GPSWidth/2 then
							dis = -2000;
							break;
						end;						
					end;
					--print("disB2 ",tostring(dis))
					
					
					
					if dis > -2000 then
						--self.GPSsideCorrect = self.GPSWidth/2-dis;
						sideCorrectTarget = self.GPSWidth/2-dis;
					elseif disA < 0 then
						--self.GPSsideCorrect = 0;
						sideCorrectTarget = 0;
					end;
					--print("2",dis," ",self.GPSsideCorrect)
				end;
				--print(tostring(self.GPSsideCorrect))
				--------
			end;
			
			--smooth target:
			if true then
				local smoothFactor = math.min(5*dt/1000,.8);
				self.GPSsideCorrect = smoothFactor*sideCorrectTarget + (1-smoothFactor)*self.GPSsideCorrect;
				
				if math.abs(self.GPSsideCorrect) < 0.01 then
					self.GPSsideCorrect = 0;
				end;
				--print(self.GPSsideCorrect)
			
			end;
			
				
			if isField then
				local dis = 0;
				local isSearchPointOnField = true;
				local stepA = 1;
				local stepB = -.05;
				if self.invertedDrivingDirection==true or self.newInvertedDrivingDirection==true or self.ddIsInverted==true or self.rufaActive==true or self.isReverseDriving then
					stepA = -stepA;
					stepB = -stepB;
				end;
				
				while isSearchPointOnField do --search fast forward (1m steps)
					dis = dis + stepA;
					local xx = x0 + dis*lhDirectionPlusMinus*self.lhdX0;
					local zz = z0 + dis*lhDirectionPlusMinus*self.lhdZ0;
					isSearchPointOnField = GPS:isField(xx,zz);						
					if math.abs(dis) > 2000 then
						break;
					end;						
				end;
				while not isSearchPointOnField do --then backtrace in small 5cm steps
					dis = dis + stepB;
					local xx = x0 + dis*lhDirectionPlusMinus*self.lhdX0;
					local zz = z0 + dis*lhDirectionPlusMinus*self.lhdZ0;
					isSearchPointOnField = GPS:isField(xx,zz);						
				end;
				
				
				self.GPSdistance2FieldBorder = math.abs(dis);
				
				if self.GPSisActiveSteering then
					-- sounds
					if self.GPSdistance2FieldBorder <= self.GPSautoStopDistance + 20 then
						if self:getIsActiveForSound() and self.GPSallowWarningSound then
							if GPS.GPSwarningSound then
								playSample(self.GPSwarningSoundId, 1, 1, 0);
							end;
							self.GPSallowWarningSound = false;
						end;
					end;
					if self.GPSdistance2FieldBorder <= self.GPSautoStopDistance then
						if not self.GPSautoStopDone then
						-- here make sound if sound is allowed
							if self.GPSautoStop then
								local startTurn = false;
								if self.GPSTurnInsteadOfAutoStop then--lets check if the next lane is still valid (we are on a field, else there would be no end2field distance)
									-- local xTest = x0 - 1.5*self.GPSWidth*lhDirectionPlusMinus*self.lhdZ0*self.GPSturningDirection - 6*lhDirectionPlusMinus*self.lhdX0;
									-- local zTest = z0 - 1.5*self.GPSWidth*lhDirectionPlusMinus*self.lhdX0*self.GPSturningDirection - 6*lhDirectionPlusMinus*self.lhdZ0;
									local xxx,yyy,zzz = getTranslation(self.GPSnode);
									local xxxW,yyyW,zzzW = localToWorld(self.GPSnode,xxx + 1.5*self.GPSWidth*self.GPSturningDirection,yyy,zzz-6)
									startTurn = GPS:isField(xxxW,zzzW);
									--startTurn = GPS:isField(xTest,zTest);
								end;
								if startTurn then
									self.GPSisTurning = true;
									self.GPSisTurningStartLane = self.GPSlaneNo;
									self.GPSforceDirectionPlusMinus = -lhDirectionPlusMinus;
									self.GPSautoStopDone = true;
								elseif self.cruiseControl.state ~= 0 and self.GPSautoStop then
									self.setCruiseControlState(self,0)
									-- if not self.isServer then
										-- g_client:getServerConnection():sendEvent(SteerableSetSpeedLevelEvent:new(self, 0));
									-- end;
									self.GPSautoStopDone = true;
								end
							end;
						end
					else
						self.GPSautoStopDone = false;
					end;
					-- sounds
					if self:getIsActiveForSound() and self.GPSallowStartSound then
						if GPS.GPSstartSound then
							playSample(self.GPSstartSoundId, 1, 1, 0);
						end;	
						self.GPSallowStartSound = false;
					end;
					if not self.GPSallowStopSound then
						self.GPSallowStopSound = true;
					end;
				end;
				
			else
				self.GPSdistance2FieldBorder = nil;
			end;
			
			-- sounds
			if self.GPSisActiveSteering then
				if self:getIsActiveForSound() and self.GPSallowStartSound then
					if GPS.GPSstartSound then
						playSample(self.GPSstartSoundId, 1, 1, 0);
					end;	
					self.GPSallowStartSound = false;
				end;
				if not self.GPSallowStopSound then
					self.GPSallowStopSound = true;
				end;
			else
				if not self.GPSallowWarningSound then
					self.GPSallowWarningSound = true;
				end;
				if not self.GPSallowStartSound then
					self.GPSallowStartSound = true;
				end;
				if self:getIsActiveForSound() and self.GPSallowStopSound then
					if GPS.GPSstopSound then
						playSample(self.GPSstopSoundId, 1, 1, 0);
					end;	
					self.GPSallowStopSound = false;
				end;
			end;
			
			if self.GPSshowLines then --here starts line generation:
				--local refNode = getParent(self.GPSnode);
				local refNode = self.GPSnode;
				local rx,_,rz = getWorldTranslation(refNode);
				
				local k
				local lineAx
				local lineAy
				local lineAz
				local lineBx
				local lineBy
				local lineBz
				
				local r = 0;
				local g = .8;
				local b = 0;
				local kmin = 0;
				local kmax = 30;
				local step = 2;
				local stepSize = 1.0; --1.0!
				
				local offsetLine = 0;
				if self.GPS_LRoffset ~= 0 then
					offsetLine = 1;
				end
				for kk = -1,1+offsetLine,1 do
				
					if kk == 0 then --middle line
						r = GPS.Config.line_center.r
						g = GPS.Config.line_center.g
						b = GPS.Config.line_center.b
						-- r=0.1;
						-- g=.6;
						-- b=0.1;
						kmin = GPS.Config.line_center.startPoint;
						kmax = GPS.Config.line_center.endPoint;
						step = GPS.Config.line_center.step;
						stepSize = GPS.Config.line_center.stepSize;
					elseif math.abs(kk) == 1 then --boundary lines
						-- r=.8;
						-- g = 0;
						-- b=0;
						r = GPS.Config.line_side.r
						g = GPS.Config.line_side.g
						b = GPS.Config.line_side.b
						-- kmin = -17;
						-- kmax = 8;
						kmin = GPS.Config.line_side.startPoint;
						kmax = GPS.Config.line_side.endPoint;
						step = GPS.Config.line_side.step;
						stepSize = GPS.Config.line_side.stepSize;
						if self.GPSclickTimer > 0 then --not self.GPSangleModeLS13 and
							kmax = 200;
						end
						--step = 2;
					elseif kk == 2 then --offset line
						-- r=.0;
						-- g = 0;
						-- b= 0.7;
						r = GPS.Config.line_offset.r
						g = GPS.Config.line_offset.g
						b = GPS.Config.line_offset.b
						kmin = GPS.Config.line_offset.startPoint;
						kmax = GPS.Config.line_offset.endPoint;
						step = GPS.Config.line_offset.step;
						stepSize = GPS.Config.line_offset.stepSize;
					end;
					
					local line0x = 0;
					local line0z = 0;
					if kk < 2 then
						line0x = rx + self.GPSWidth*self.lhdZ0*(beta+kk/2)
						line0z = rz - self.GPSWidth*self.lhdX0*(beta+kk/2)
					else
						local offsetFactor = 1.0;
						if self.GPSturnOffset then
							offsetFactor = lhDirectionPlusMinus;
						end;
						line0x = rx + self.GPSWidth*self.lhdZ0*(beta-offsetFactor*lhDirectionPlusMinus*self.GPS_LRoffset/self.GPSWidth)
						line0z = rz - self.GPSWidth*self.lhdX0*(beta-offsetFactor*lhDirectionPlusMinus*self.GPS_LRoffset/self.GPSWidth)					
					end
					
					--local line0y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, line0x, posy, line0z) + .2;					
					
					local y_offset = .2;
					if self.GPSraiseLines then
						y_offset = 2.5;
					end;
					
					local movDir = self.GPSmovingDirection;
										
					for k = kmin,kmax,step do
						lineAx = line0x + stepSize*k*lhDirectionPlusMinus*self.lhdX0*movDir;
						lineAz = line0z + stepSize*k*lhDirectionPlusMinus*self.lhdZ0*movDir;
						lineAy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, lineAx, 0, lineAz) + .2 + math.max(math.min(2*(k-kmin-5)/(kmax-kmin),1),0)*(y_offset-.2);
						
						lineBx = line0x + stepSize*(k+1)*lhDirectionPlusMinus*self.lhdX0*movDir;
						lineBz = line0z + stepSize*(k+1)*lhDirectionPlusMinus*self.lhdZ0*movDir;
						lineBy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, lineBx, 0, lineBz) + .2 + math.max(math.min(2*(k-kmin-4)/(kmax-kmin),1),0)*(y_offset-.2);
						
						drawDebugLine(lineAx, lineAy, lineAz, r, g, b, lineBx, lineBy, lineBz, r, g, b);		
					end;

				end;
			end;
		else
			self.GPSisActiveSteering= false;
			self.GPSsteeringOffset = 0;
			if GPS.stopMouse then
				GPS.stopMouse = false;
				InputBinding.setShowMouseCursor(false);
			end;
		end;
	end
	
	if needPushEvent then		
        if g_server ~= nil then
            g_server:broadcastEvent(GPS_Event:new(self, self.lhX0,self.lhZ0,self.lhdX0,self.lhdZ0,self.GPSWidth,self.GPS_LRoffset,self.GPSautoStop,self.GPSautoStopDistance,self.GPSTurnInsteadOfAutoStop,self.GPSturningMinFreeLanes,self.GPSturningDirection,self.GPSlaneNoOffset,self.GPSturnOffset), nil, nil, self);
        else
            g_client:getServerConnection():sendEvent(GPS_Event:new(self, self.lhX0,self.lhZ0,self.lhdX0,self.lhdZ0,self.GPSWidth,self.GPS_LRoffset,self.GPSautoStop,self.GPSautoStopDistance,self.GPSTurnInsteadOfAutoStop,self.GPSturningMinFreeLanes,self.GPSturningDirection,self.GPSlaneNoOffset,self.GPSturnOffset));
        end;	
	end
end;

function GPS:draw()

	--f1 box txt "0 ,"
	if not self.GPSActive then
		g_currentMission:addHelpButtonText(Steerable.turnOn, InputBinding.GPS_OnOff,nil,GS_PRIO_LOW);
	else
		g_currentMission:addHelpButtonText(Steerable.turnOff, InputBinding.GPS_OnOff,nil,GS_PRIO_LOW);
		g_currentMission:addHelpButtonText(Steerable.GPS_InfoMode, InputBinding.GPS_InfoMode,nil,GS_PRIO_LOW);
		--g_currentMission:addHelpButtonText(Steerable.GPS_userInput, InputBinding.GPS_userInput);
		
		-- name
		if GPS.Store[self.GPS_storeSlot] ~= nil then
			local slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName;
			if slotName ~= nil and slotName ~= "" then
				g_currentMission:addExtraPrintText(string.format(Steerable.GPS_NAME, self.typeDesc) .. "("..tostring(self.GPS_storeSlot).."): "..tostring(GPS.Store[self.GPS_storeSlot].GPS_slotName));
			end;
		end;
	end;
	

	if self.GPSshowMode < 3 and self.GPSActive then
	
		---------------------------------
		if true then
			--local isPDA = Utils.getNoNil(g_currentMission.missionPDA.showPDA,false) or Utils.getNoNil(self.acGuiActive,false);
			local isPDA = false; --LS15
			if isPDA and self.GPSshowMode>1 then
				self.GPSshowMode = 1;
			end;
			for mode=1,self.GPSshowMode do
				local hudField = GPS.GPS_HUDfields[mode];
				
				
				if hudField.showOnPDA then
					if isPDA then
						hudField.background:setPosition(hudField.pdaX, hudField.pdaY)
					else
						hudField.background:setPosition(hudField.normalX, hudField.normalY)
					end;
				end;
				
				hudField.background:render();
				
				for o,ov in pairs(GPS.GPS_HUDfields[mode].boolOverlays) do
					if ov.Ncond > 0 then
						local c1 = self[ov.cond1];
						local c2 = true;
						if ov.cond1Inv then
							c1 = not c1;
						end;
						if ov.Ncond > 1 then
							c2 = self[ov.cond2];
							if ov.cond2Inv then
								c2 = not c2;
							end;
						end;
						if c1 and c2 then
							if isPDA then
								if hudField.showOnPDA then
									ov.overlay:setPosition(hudField.pdaX, hudField.pdaY);
									ov.overlay:render();
								end;
							else
								if hudField.showOnPDA then
									ov.overlay:setPosition(hudField.normalX, hudField.normalY)
								end;
								ov.overlay:render();
							end;			
						end;				
					end;
				end;
				
				
				
				setTextAlignment(RenderText.ALIGN_LEFT); 
				setTextBold(false);
				setTextColor(.8,.8,.8,.9);
				
				for t,txt in pairs(GPS.GPS_HUDfields[mode].TXTfields) do
					local doTxt = true;
					if txt.boolean~= nil then
						if txt.invert then
							doTxt = not self[txt.boolean];
						else
							doTxt = self[txt.boolean];
						end;
					end;
					
					
					if doTxt then
						if txt.alignCenter then
							setTextAlignment(RenderText.ALIGN_CENTER); 
						else
							setTextAlignment(RenderText.ALIGN_LEFT); 
						end;
						local x = txt.xCoord;
						local y = txt.yCoord;
						if isPDA then
							y = Utils.getNoNil(txt.yPDA,y);
						end;
						
						setTextBold(false)
						if txt.boldBoolean ~= nil then
							if self[txt.boldBoolean] then
								setTextBold(true);
							end;
						end;
						
						renderText(x,y,txt.size,string.format(txt.str,self[txt.varStr]));
					end;
					setTextAlignment(RenderText.ALIGN_LEFT);
					setTextBold(false);
				end;

				
				for b,button in pairs(GPS.GPS_HUDfields[mode].buttons) do
					if button.pressedOverlay~= nil then
						if InputBinding.isPressed(button.binding) then
							if InputBinding.isPressed(InputBinding.GPS_adjustCourseModifier) == button.modifier then
								button.pressedOverlay:render();
							end;
						end;						
					end;				
				end;

				
			end;
		end;
	end
end;


function GPS:getSaveAttributesAndNodes(nodeIdent)
	local attributes = "";
	if self.lhX0 ~= nil then
		attributes = 'GPS_x="'..self.lhX0..'" '		
		attributes = attributes..'GPS_z="'..self.lhZ0..'" '
		attributes = attributes..'GPS_dx="'..self.lhdX0..'" '
		attributes = attributes..'GPS_dz="'..self.lhdZ0..'" '
		attributes = attributes..'GPS_Width="'..self.GPSWidth..'" '
		attributes = attributes..'GPS_Offset="'..self.GPS_LRoffset..'" '
		attributes = attributes..'GPS_Name="'..self.GPS_slotName..'" '		
	end
	
	if GPS.Store~= nil then
		local strNrs = '';
		local newStr = '';
		for k,storeItem in pairs(GPS.Store) do
			strNrs = strNrs ..tostring(k)..' ';
			local prefix = 'GPSstore'..tostring(k);
			newStr = newStr .. prefix .. '_x="'..tostring(GPS.Store[k].lhX0)..'" ';
			newStr = newStr .. prefix .. '_z="'..tostring(GPS.Store[k].lhZ0)..'" ';
			newStr = newStr .. prefix .. '_dx="'..tostring(GPS.Store[k].lhdX0)..'" ';
			newStr = newStr .. prefix .. '_dz="'..tostring(GPS.Store[k].lhdZ0)..'" ';
			newStr = newStr .. prefix .. '_w="'..tostring(GPS.Store[k].GPSWidth)..'" ';
			newStr = newStr .. prefix .. '_o="'..tostring(GPS.Store[k].GPS_LRoffset)..'" ';
			if GPS.Store[k].GPS_slotName ~= nil then
				newStr = newStr .. prefix .. '_n="'..tostring(GPS.Store[k].GPS_slotName)..'" ';
			end;	
		end;
		strNrs = 'GPSstoreInv="'..strNrs..'" ';
		
		attributes = attributes..strNrs..newStr;
	end;
	return attributes
end;



-- function driveControl:postLoad(savegame) 

	-- if savegame ~= nil then
		-- self.driveControl.fourWDandDifferentials.fourWheel = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key.."#fourWheel"),false);
		-- self.driveControl.fourWDandDifferentials.diffLockFront = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key.."#diffLockFront"),false);
		-- self.driveControl.fourWDandDifferentials.diffLockBack = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key.."#diffLockBack"),false);
	-- end

-- end;





function GPS:postLoad(savegame)	
	if savegame ~= nil and not savegame.resetVehicles then
		local x = getXMLFloat(savegame.xmlFile, savegame.key.."#GPS_x");
		if x ~= nil then
			self.lhX0 = x;
			
			local z = getXMLFloat(savegame.xmlFile, savegame.key.."#GPS_z");
			self.lhZ0 = z;

			local dx = getXMLFloat(savegame.xmlFile, savegame.key.."#GPS_dx");
			self.lhdX0 = dx;
			local dz = getXMLFloat(savegame.xmlFile, savegame.key.."#GPS_dz");
			self.lhdZ0 = dz;
			local w = getXMLFloat(savegame.xmlFile, savegame.key.."#GPS_Width");
			self.GPSWidth = w;
			local o = getXMLFloat(savegame.xmlFile, savegame.key.."#GPS_Offset");
			self.GPS_LRoffset = Utils.getNoNil(o,0); -- o,0 
			local n = getXMLString(savegame.xmlFile, savegame.key.."#GPS_Name");
			self.GPS_slotName = Utils.getNoNil(n,"");
						
			self.GPSfirstrun = false;
			
			if GPS.Store == nil then
				GPS.Store = {};
			end;
			
			local inventory = getXMLString(savegame.xmlFile, savegame.key.."#GPSstoreInv");

			if inventory ~= nil then
				local storeKeys = Utils.splitString(" ", inventory);
				for k,storeKey in pairs(storeKeys) do
					if tonumber(storeKey) ~= nil then
						if GPS.Store[tonumber(storeKey)] == nil then
							GPS.Store[tonumber(storeKey)] = {};
						end;
						local fieldname = '#GPSstore'..tostring(storeKey);
						
						local x = getXMLFloat(savegame.xmlFile, savegame.key..fieldname..'_x');					
						GPS.Store[tonumber(storeKey)].lhX0 = x;
						local z = getXMLFloat(savegame.xmlFile, savegame.key..fieldname..'_z');					
						GPS.Store[tonumber(storeKey)].lhZ0 = z;
						local dx = getXMLFloat(savegame.xmlFile, savegame.key..fieldname..'_dx');					
						GPS.Store[tonumber(storeKey)].lhdX0 = dx;
						local dz = getXMLFloat(savegame.xmlFile, savegame.key..fieldname..'_dz');					
						GPS.Store[tonumber(storeKey)].lhdZ0 = dz;
						local w = getXMLFloat(savegame.xmlFile, savegame.key..fieldname..'_w');					
						GPS.Store[tonumber(storeKey)].GPSWidth = w;
						local o = getXMLFloat(savegame.xmlFile, savegame.key..fieldname..'_o');					
						GPS.Store[tonumber(storeKey)].GPS_LRoffset = o;
						local n = getXMLString(savegame.xmlFile, savegame.key..fieldname..'_n');					
						GPS.Store[tonumber(storeKey)].GPS_slotName = Utils.getNoNil(n,"");
					end;
				end;
			end;
		end;
		
	end;
	
end;



-- function GPS:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	-- if not resetVehicles then
		-- local x = getXMLFloat(self.xmlFile, key.."#GPS_x");
		-- if x ~= nil then
			-- self.lhX0 = x;
			
			-- local z = getXMLFloat(self.xmlFile, key.."#GPS_z");
			-- self.lhZ0 = z;

			-- local dx = getXMLFloat(self.xmlFile, key.."#GPS_dx");
			-- self.lhdX0 = dx;
			-- local dz = getXMLFloat(self.xmlFile, key.."#GPS_dz");
			-- self.lhdZ0 = dz;
			-- local w = getXMLFloat(self.xmlFile, key.."#GPS_Width");
			-- self.GPSWidth = w;
			-- local o = getXMLFloat(self.xmlFile, key.."#GPS_Offset");
			-- self.GPS_LRoffset = Utils.getNoNil(o,0); -- o,0 
			-- local n = getXMLString(self.xmlFile, key.."#GPS_Name");
			-- self.GPS_slotName = Utils.getNoNil(n,"");
						
			-- self.GPSfirstrun = false;
			
			-- if GPS.Store == nil then
				-- GPS.Store = {};
			-- end;
			
			-- local inventory = getXMLString(self.xmlFile, key.."#GPSstoreInv");

			-- if inventory ~= nil then
				-- local storeKeys = Utils.splitString(" ", inventory);
				-- for k,storeKey in pairs(storeKeys) do
					-- if tonumber(storeKey) ~= nil then
						-- if GPS.Store[tonumber(storeKey)] == nil then
							-- GPS.Store[tonumber(storeKey)] = {};
						-- end;
						-- local fieldname = '#GPSstore'..tostring(storeKey);
						
						-- local x = getXMLFloat(xmlFile, key..fieldname..'_x');					
						-- GPS.Store[tonumber(storeKey)].lhX0 = x;
						-- local z = getXMLFloat(xmlFile, key..fieldname..'_z');					
						-- GPS.Store[tonumber(storeKey)].lhZ0 = z;
						-- local dx = getXMLFloat(xmlFile, key..fieldname..'_dx');					
						-- GPS.Store[tonumber(storeKey)].lhdX0 = dx;
						-- local dz = getXMLFloat(xmlFile, key..fieldname..'_dz');					
						-- GPS.Store[tonumber(storeKey)].lhdZ0 = dz;
						-- local w = getXMLFloat(xmlFile, key..fieldname..'_w');					
						-- GPS.Store[tonumber(storeKey)].GPSWidth = w;
						-- local o = getXMLFloat(xmlFile, key..fieldname..'_o');					
						-- GPS.Store[tonumber(storeKey)].GPS_LRoffset = o;
						-- local n = getXMLString(xmlFile, key..fieldname..'_n');					
						-- GPS.Store[tonumber(storeKey)].GPS_slotName = Utils.getNoNil(n,"");
					-- end;
				-- end;
			-- end;
		-- end;
	
	-- end;
	-- return BaseMission.VEHICLE_LOAD_OK;
-- end

function GPS:delete()	
end


function GPS.xMinMaxAI(self,object,xmin,xmax)
	
	if object.aiLeftMarker ~= nil and object.aiRightMarker ~= nil then		
		local x1,y1,z1 = getWorldTranslation(object.aiLeftMarker)
		local x2,y2,z2 = getWorldTranslation(object.aiRightMarker)
		local lx1,ly1,lz1 = worldToLocal(self.GPSnode,x1,y1,z1)
		local lx2,ly2,lz2 = worldToLocal(self.GPSnode,x2,y2,z2)		
		
		if lx1 < xmin then
			xmin = lx1;
		end
		if lx1 > xmax then
			xmax = lx1;
		end
		if lx2 < xmin then
			xmin = lx2;
		end
		if lx2 > xmax then
			xmax = lx2;
		end
	end
	
	return xmin, xmax;
end;

function GPS.xMinMaxAreas(self,areas,xmin,xmax)

	if areas ~= nil then
		for _,cuttingArea in pairs(areas) do
			if self:getIsWorkAreaActive(cuttingArea) then

				local x1,y1,z1 = getWorldTranslation(cuttingArea.start)
				local x2,y2,z2 = getWorldTranslation(cuttingArea.width)
				local x3,y3,z3 = getWorldTranslation(cuttingArea.height)
				local lx1,ly1,lz1 = worldToLocal(self.GPSnode,x1,y1,z1)
				local lx2,ly2,lz2 = worldToLocal(self.GPSnode,x2,y2,z2)
				local lx3,ly3,lz3 = worldToLocal(self.GPSnode,x3,y3,z3)
				
				if lx1 < xmin then
					xmin = lx1;
				end
				if lx1 > xmax then
					xmax = lx1;
				end
				if lx2 < xmin then
					xmin = lx2;
				end
				if lx2 > xmax then
					xmax = lx2;
				end
				if lx3 < xmin then
					xmin = lx3;
				end
				if lx3 > xmax then
					xmax = lx3;
				end
			end
		end
	end

	return xmin, xmax;
end

function GPS:isField(x,z) --new method supplied by Koper. Thanks! :)
	--return (getDensityAtWorldPos(g_currentMission.terrainDetailId, x, z) % 16) > 0; 
	return (getDensityAtWorldPos(g_currentMission.terrainDetailId, x, 0, z) % 16) > 0; 
	
end; 

-- old function, looks like this caused the fps-problems.
-- function GPS:isField(x,z)
	-- local cultivatorChannel = Utils.getDensity(g_currentMission.terrainDetailId, g_currentMission.cultivatorChannel, x, z, x, z, x, z);
	-- local ploughChannel = Utils.getDensity(g_currentMission.terrainDetailId, g_currentMission.ploughChannel, x, z, x, z, x, z);
	-- local sowingChannel = Utils.getDensity(g_currentMission.terrainDetailId, g_currentMission.sowingChannel, x, z, x, z, x, z);
	-- local potatoeChannel = Utils.getDensity(g_currentMission.terrainDetailId, g_currentMission.sowingWidthChannel, x, z, x, z, x, z);
	-- if cultivatorChannel > 0 or ploughChannel > 0 or sowingChannel > 0 or potatoeChannel > 0 then
		-- return true;
	-- else
		-- return false;
	-- end;
-- end;


function GPS:newMouseEvent(superFunc,posX, posY, isDown, isUp, button)
	
	if GPS.stopMouse then
		local x = InputBinding.mouseMovementX;
		local y = InputBinding.mouseMovementY;
		InputBinding.mouseMovementX = 0;
		InputBinding.mouseMovementY = 0;
		superFunc(self, posX, posY, isDown, isUp, button)
		InputBinding.mouseMovementX = x;
		InputBinding.mouseMovementY = y;
	else	
		superFunc(self, posX, posY, isDown, isUp, button)
	end;
end;

function GPS:checkIsDedi()
	return g_dedicatedServerInfo ~= nil;
	--local pixelX, pixelY = getScreenModeInfo(getScreenMode());
	--return pixelX*pixelY < 1;
end;

function GPS:prepareHUD()
	
	if GPS.isHUDloaded then
		return;
	end;
	
	GPS.Config = GPS:loadHUDConfig()
	--print("HUD size: "..tostring(hudSize))
	
	local yFields = 0.01
	local xFields = 0.01;
	--yFields = (1080-818)/1080;
	
	local Nfields = 2;
	local aspectFields = {0.5,2}; -- {1,2} means background 1 is 256x256 and background 2 is 256x512
	local PDAoffset = .45* 0.5625 * 1.3333333333333333;-- - 0.8*yFields;
	
	local pixelX, pixelY = getScreenModeInfo(getScreenMode());
	
	pixelX = pixelX/GPS.Config.hud;
	pixelY = pixelY/GPS.Config.hud;
	
	local width_image = 256;
	local width = width_image/pixelX
	local height_0 = width_image/pixelY
	yFields = yFields *pixelX/pixelY;
	
	GPS.GPS_HUDfields = {};
	local yOff = 0.22;
	for k=1,Nfields do
		local hudField = {};
		path = Utils.getFilename("HUD/Block"..tostring(k) .. ".dds", GPS_directory);
					
		hudField.background = Overlay:new("background"..tostring(k), path, xFields, yFields+yOff, width, height_0*aspectFields[k]); 
		hudField.showOnPDA = k==1;
		if hudField.showOnPDA then
			hudField.normalX = xFields;
			hudField.normalY = yFields+yOff;
			hudField.pdaX = hudField.normalX;
			hudField.pdaY = hudField.normalY + PDAoffset;		
		end;
		
		-----------------txt fields ------------------------------
		hudField.TXTfields = {};		
		if k == 1 or k == 2 then --monitor
			--def vars
			local txtField = {};
			local xPix = {};
			local yPix = {};
			local str = {};
			local varStr = {};
			local boolean = {};
			local invert = {};
			local txtSize = {};
			local alignCenter = {};
			local boldBoolean = {}; 
			
			if k == 1 then--fill vars monitor
				xPix = {224,181,33,125,228,33,136};
				yPix = {120,120,46,54,60,80,42};
				str = {"%s","%s","%s","%2.1f","%2.1f","%d","%s"};
				varStr = {"GPS_HUD_distanceStr","GPS_HUD_OffsetStr","GPS_HUD_rowStr","GPSWidth","GPSautoStopDistance","GPSturningMinFreeLanes","GPScurrentToolTip"};
				txtSize = {12,12,16,14,12,16,12};
				boolean = {nil,nil,nil,nil,"GPSautoStop",nil,nil};
				invert =  {nil,nil,nil,nil,false,nil,nil};
				alignCenter = {true,true,false,true,true,false,true};
				boldBoolean = {nil,nil,nil,nil,nil,nil,nil};
			elseif k==2 then --big control screen
				xPix = {63};
				yPix = {300};
				str = {"%d"};
				varStr = {"GPS_storeSlot"};
				txtSize = {16};
				boolean = {nil};
				invert =  {nil};
				alignCenter = {true};
				boldBoolean = {"GPS_HUD_Slot_exists"};
			end;
			
			local Ntxt = table.getn(xPix);
			if Ntxt>0 then
				for t = 1,Ntxt do
					local txt = {};					
					txt.xCoord = xFields + (xPix[t]/pixelX);
					txt.yCoord = yFields + (width_image*aspectFields[k]-yPix[t])/pixelY + yOff;
					if hudField.showOnPDA then
						txt.yPDA = txt.yCoord + PDAoffset;
					end;
					txt.str = str[t];
					txt.varStr = varStr[t];
					txt.size = txtSize[t]/pixelY;
					txt.boolean = boolean[t];
					txt.invert = invert[t];
					txt.alignCenter = alignCenter[t];
					txt.boldBoolean = boldBoolean[t];
					hudField.TXTfields[t] = txt;
				end;
			else
				hudField.TXTfields = {};
			end;
		end;
		
		
		----------------------------overlays controlled by booleans
		hudField.boolOverlays = {};
		if k == 1 or k == 2 then
			local files = {};
			local Ncond = {};
			local cond1 = {};
			local cond1Inv = {};
			local cond2 = {};
			local cond2Inv = {};
			
			if k == 1 then
				files = {"gps_aus.dds","gps_passiv.dds","gps_aktiv.dds","turn_links.dds","turn_rechts.dds","turn_stop.dds","turn_aus.dds","schaltwert.dds","offset_spiegeln.dds","offset_autospiegeln.dds"};
				Ncond = {1,2,2,1,1,2,1,1,1,1};
				cond1 = {"GPSActive","GPSActive","GPSActive","GPS_HUD_AutoLeft","GPS_HUD_AutoRight","GPSautoStop","GPSautoStop","GPSautoStop","GPSturnOffset","GPSturnOffset"};
				cond1Inv = {true,false,false,false,false,false,true,false,true,false};
				cond2 = {nil,"GPSisActiveSteering","GPSisActiveSteering",nil,nil,"GPSTurnInsteadOfAutoStop",nil,nil,nil,nil};
				cond2Inv = {nil,true,false,nil,nil,true,nil,nil,nil,nil};			
			elseif k == 2 then
				files = {"autospiegeln_aktiv.dds","lenkrad_aktiv.dds","turn_rechts_aktiv.dds","turn_links_aktiv.dds","turn_stop_aktiv.dds","linien_unten_aktiv.dds","linien_hochgezogen_aktiv.dds","B2_GPS_aktiv.dds","B2_GPS_passiv.dds"}
				Ncond = {1,1,1,1,2,2,2,2,2};
				cond1 = {"GPSturnOffset","GPSanalogControllerMode","GPS_HUD_AutoRight","GPS_HUD_AutoLeft","GPSautoStop","GPSshowLines","GPSshowLines","GPSActive","GPSActive"};
				cond1Inv = {false,false,false,false,false,false,false,false,false};
				cond2 = {nil,nil,nil,nil,"GPSTurnInsteadOfAutoStop","GPSraiseLines","GPSraiseLines","GPSisActiveSteering","GPSisActiveSteering"};
				cond2Inv = {nil,nil,nil,nil,true,true,false,false,true};
			end;
			
						
			local Nfiles = table.getn(files);
			
			if Nfiles > 0 then
				for o=1,Nfiles do
					local newOv = {};
					local path =  Utils.getFilename("HUD/"..files[o], GPS_directory);
					newOv.overlay = Overlay:new("overlay"..tostring(k).."."..tostring(o), path, xFields, yFields+yOff, width, height_0*aspectFields[k]); 
					newOv.Ncond = Ncond[o];
					newOv.cond1 = cond1[o];
					newOv.cond1Inv = cond1Inv[o];
					newOv.cond2 = cond2[o];
					newOv.cond2Inv = cond2Inv[o];
					
					hudField.boolOverlays[o] = newOv;
				end;
			end;
			
		end;
		----------------------buttons----------------------
		hudField.buttons = {};
		if k == 2 then -- buttons
			
			local xBpix = {137,176,215,215,176,137,176,215,9,49,87,9,49,9,88,137,176,215,176,215,120,137,49,49,9,88,88,9,49,9};
			local yBpix = {305,305,305,365,365,365,402,402,365,365,365,403,403,465,500,500,500,500,465,465,444,465,500,465,500,267,305,267,267,305};
			local wBpix = {32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32};
			local hBpix = {32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32};
			local bindings = {InputBinding.GPS_WidthPlus,InputBinding.GPS_WidthMinus,InputBinding.GPS_AutoWidth,InputBinding.GPS_OffsetLeft,InputBinding.GPS_OffsetRight,InputBinding.GPS_OffsetZero,InputBinding.GPS_InvertOffset_V3,InputBinding.GPS_OffsetAutoInvert,InputBinding.GPS_shiftParallelLeft,InputBinding.GPS_shiftParallelRight,InputBinding.GPS_90Grad,InputBinding.GPS_turnRight,InputBinding.GPS_turnLeft,InputBinding.GPS_lineMode,InputBinding.GPS_wheelMode,InputBinding.GPS_endFieldMode,InputBinding.GPS_shiftParallelLeft,InputBinding.GPS_shiftParallelRight,InputBinding.GPS_turnLeft,InputBinding.GPS_turnRight,InputBinding.GPS_minFreeLanesPlus,InputBinding.GPS_minFreeLanesMinus,InputBinding.GPS_Init,InputBinding.GPS_NearestSteerable,InputBinding.GPS_SteeringOnOff,InputBinding.GPS_storePlus,InputBinding.GPS_storeMinus,InputBinding.GPS_Load,InputBinding.GPS_Save,InputBinding.GPS_Delete}
			local modifier = {true,true,true,true,true,true,true,false,true,true,true,true,true,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false};
			local pressedFiles = {"arbeitsbreite_plus.dds","arbeitsbreite_minus.dds","arbeitsbreite_auto_aktiv.dds","offset_minus.dds","offset_plus.dds","offset_null.dds","spiegeln_aktiv.dds",nil,"links_parallel_aktiv.dds","rechts_parallel_aktiv.dds","90grad_drehen_aktiv.dds","turn_links_winkel_aktiv.dds","turn_rechts_winkel_aktiv.dds",nil,nil,nil,"links_wenden_aktiv.dds","rechts_wenden_aktiv.dds","schaltabstand_plus.dds","schaltabstand_minus.dds","min_free_lanes_plus.dds","min_free_lanes_minus.dds","new_mouseover.dds","import_aktiv.dds",nil,"save_load_plus.dds","Save_load_minus.dds","save_aktiv.dds","load_aktiv.dds","delete.dds"};
			local toolTips = {Steerable.WidthPlus,Steerable.WidthMinus,Steerable.AutoWidth,Steerable.OffsetLeft,Steerable.OffsetRight,Steerable.OffsetZero,Steerable.InvertOffset,Steerable.OffsetAutoInvert,Steerable.ShiftParallelLeft,Steerable.ShiftParallelRight,Steerable.Degree90,Steerable.RotateLeft,Steerable.RotateRight,Steerable.GPS_lineMode,Steerable.GPS_wheelMode,Steerable.GPS_endFieldMode,Steerable.TurnLeft,Steerable.TurnRight,Steerable.AutoStopDistPlus,Steerable.AutoStopDistMinus,Steerable.MinFreeLanesPlus,Steerable.MinFreeLanesMinus,Steerable.Initiate,Steerable.NearestSteerable,Steerable.SteeringOnOff,Steerable.StorePlus,Steerable.StoreMinus,Steerable.Load,Steerable.Save,Steerable.Delete};
			local Nbuttons = table.getn(xBpix);
			for b=1,Nbuttons do
				local button = {};
				button.xCoord = {};
				button.yCoord = {};
				button.xCoord[1] = xFields + (xBpix[b]/pixelX);
				button.xCoord[2] = xFields + ((xBpix[b] + wBpix[b])/pixelX);
				button.yCoord[1] = yFields + (width_image*aspectFields[k]-yBpix[b])/pixelY + yOff;
				button.yCoord[2] = yFields + (width_image*aspectFields[k]-yBpix[b]+hBpix[b])/pixelY +yOff;
				button.binding = bindings[b];
				button.modifier = modifier[b];
				if pressedFiles[b]~= nil then
					local path =  Utils.getFilename("HUD/"..pressedFiles[b], GPS_directory);
					button.pressedOverlay = Overlay:new("pressed"..tostring(k).."."..tostring(b), path, xFields, yFields+yOff, width, height_0*aspectFields[k]); 
				end;
				button.toolTip = toolTips[b];
				
				hudField.buttons[b] = button;
			end;
		end;
		
		--GPS.GPS_HUDfields[k].TXTfields
		
		GPS.GPS_HUDfields[k] = hudField;
		yOff = yOff - yFields + height_0*aspectFields[k];
	end;
	GPS.isHUDloaded = true;
end;


function GPS:writeStream(streamId, connection)
	local NoCoord = not(self.lhX0 == nil);
	streamWriteBool(streamId, NoCoord);
	if NoCoord then
		streamWriteFloat32(streamId, self.lhX0);
		streamWriteFloat32(streamId, self.lhZ0);
		streamWriteFloat32(streamId, self.lhdX0);
		streamWriteFloat32(streamId, self.lhdZ0);
	end
	streamWriteFloat32(streamId, self.GPSWidth);
	streamWriteFloat32(streamId, self.GPS_LRoffset);
	streamWriteString(streamId, self.GPS_slotName);
	
	streamWriteBool(streamId, self.GPSautoStop);
	streamWriteFloat32(streamId, self.GPSautoStopDistance);
	streamWriteBool(streamId, self.GPSTurnInsteadOfAutoStop);
	streamWriteFloat32(streamId, self.GPSturningMinFreeLanes);
	streamWriteFloat32(streamId, self.GPSturningDirection);
	streamWriteFloat32(streamId, self.GPSlaneNoOffset);
	streamWriteBool(streamId, self.GPSturnOffset);
	
	
	local nStore = 0;
	if GPS.Store ~= nil then
		for k,item in pairs(GPS.Store) do
			nStore = nStore + 1;
		end;
	end
	
	streamWriteUIntN(streamId, nStore, 8);
	--print("Server: nStore "..tostring(nStore))
	if nStore > 0 then
		for k,item in pairs(GPS.Store) do
			streamWriteUIntN(streamId, k, 8);
			streamWriteFloat32(streamId, item.lhdX0);
			streamWriteFloat32(streamId, item.lhdZ0);
			streamWriteFloat32(streamId, item.lhX0);
			streamWriteFloat32(streamId, item.lhZ0);
			streamWriteFloat32(streamId, item.GPSWidth);
			streamWriteFloat32(streamId, item.GPS_LRoffset);
			streamWriteString(streamId, item.GPS_slotName);			
		end;	
	end;
end;

function GPS:readStream(streamId, connection)
	if streamReadBool(streamId) then
		self.lhX0 = streamReadFloat32(streamId);
		self.lhZ0 = streamReadFloat32(streamId);
		self.lhdX0 = streamReadFloat32(streamId);
		self.lhdZ0 = streamReadFloat32(streamId);
	end;
	self.GPSWidth = streamReadFloat32(streamId);
	self.GPS_LRoffset = streamReadFloat32(streamId);
	self.GPS_slotName = streamReadString(streamId);

	self.GPSautoStop = streamReadBool(streamId);
	self.GPSautoStopDistance = streamReadFloat32(streamId);
	self.GPSTurnInsteadOfAutoStop = streamReadBool(streamId);
	self.GPSturningMinFreeLanes = streamReadFloat32(streamId);
	self.GPSturningDirection = streamReadFloat32(streamId);
	self.GPSlaneNoOffset = streamReadFloat32(streamId);
	self.GPSturnOffset = streamReadBool(streamId);
	
	
	local nStore = streamReadUIntN(streamId, 8);
	if nStore > 0 then
		if GPS.Store == nil then
			GPS.Store = {};
		end;
		for k = 1,nStore do
			local slot = streamReadUIntN(streamId, 8);
			GPS.Store[slot] = {};
			GPS.Store[slot].lhdX0 = streamReadFloat32(streamId);
			GPS.Store[slot].lhdZ0 = streamReadFloat32(streamId);
			GPS.Store[slot].lhX0 = streamReadFloat32(streamId);
			GPS.Store[slot].lhZ0 = streamReadFloat32(streamId);
			GPS.Store[slot].GPSWidth = streamReadFloat32(streamId);
			GPS.Store[slot].GPS_LRoffset = streamReadFloat32(streamId);	
			GPS.Store[slot].GPS_slotName = streamReadString(streamId);		
		end;
	end;

	if self.lhX0 == nil then
		self.GPSfirstrun = true;
	else
		self.GPSfirstrun = false;
	end;
end;



function GPS:transferMouse2InputBinding()
	if GPS.mouse2InputBindingsLastTime ~= g_currentMission.time then	
		for k,iB in pairs(InputBinding.actions) do
			if iB.isMousePressed ~= nil then
				if iB.isMousePressed then
					iB.lastIsPressed = true;
				end;
			end;
			if iB.isMouseEvent ~= nil then
				if iB.isMouseEvent then
					iB.hasEvent = true;
					iB.isMouseEvent = false;
				end;
			end;
		end;
		GPS.mouse2InputBindingsLastTime = g_currentMission.time;
	end;
end;

function GPS:loadHUDConfig()
	
	local hudXml;
	local file = g_modsDirectory.."/GPS_config.xml";
			
	local line_center = {str = "line_center", r = 0.1,g=0.6,b=.1,stepSize = 1,step = 1,startPoint = 0, endPoint = 25}
	local line_side = {str = "line_side", r = 0.8,g=0.1,b=.1,stepSize = 1,step = 2,startPoint = -17, endPoint = 8}
	local line_offset = {str = "line_offset", r = 0.1,g=0.1,b=.8,stepSize = 1,step = 1.5,startPoint = 0, endPoint = 25}	
	local res = {line_center = line_center, line_offset = line_offset, line_side = line_side};
			
	if fileExists(file) then
		res.hud = 1.0;
		hudXml = loadXMLFile("GPS_HUD_XML", file, "GPS");
		local startSound = getXMLBool(hudXml, "GPS.GPSsound.StartSound");
		local stopSound = getXMLBool(hudXml, "GPS.GPSsound.StopSound");
		local warningSound = getXMLBool(hudXml, "GPS.GPSsound.WarningSound");
		if startSound == nil or stopSound == nil or warningSound == nil then
			if startSound == nil then
				startSound = true;
				setXMLBool(hudXml, "GPS.GPSsound.StartSound", startSound);
			end;
			if stopSound == nil then
				stopSound = true;
				setXMLBool(hudXml, "GPS.GPSsound.StopSound", stopSound);
			end;
			if warningSound == nil then
				warningSound = true;
				setXMLBool(hudXml, "GPS.GPSsound.WarningSound", warningSound);
			end;
			saveXMLFile(hudXml);
		end;	
	else --create std file instead:
		hudXml = createXMLFile("GPS_HUD_XML", file, "GPS");

		for _,field in pairs(res) do
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#r",field.r);
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#g",field.g);
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#b",field.b);			
			
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#startPoint",field.startPoint);
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#endPoint",field.endPoint);
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#stepSize",field.stepSize);
			setXMLFloat(hudXml, "GPS.GPSlines."..field.str.."#step",field.step);
		end;
		res.hud = 1.0;
		res.wheelMode = false;
		res.startSound = true;
		res.stopSound = true;
		res.warningSound = true;
		
		setXMLFloat(hudXml, "GPS.GPShud.HUDsize",res.hud);
		setXMLBool(hudXml, "GPS.GPSController.wheelmode",res.wheelMode);
		setXMLBool(hudXml, "GPS.GPSsound.StartSound",res.startSound);
		setXMLBool(hudXml, "GPS.GPSsound.StopSound",res.stopSound);
		setXMLBool(hudXml, "GPS.GPSsound.WarningSound",res.warningSound);
		
		saveXMLFile(hudXml);
		return res;
	end;
	

	if hudXml ~= nil then	
		res.hud = getXMLFloat(hudXml, "GPS.GPShud.HUDsize");
		res.wheelMode = getXMLBool(hudXml, "GPS.GPSController.wheelmode");
		res.startSound = getXMLBool(hudXml, "GPS.GPSsound.StartSound");
		res.stopSound = getXMLBool(hudXml, "GPS.GPSsound.StopSound");
		res.warningSound = getXMLBool(hudXml, "GPS.GPSsound.WarningSound");
		local fields = {"line_center","line_offset","line_side"};
		for _,field in pairs(fields) do
			res[field].r = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#r");
			res[field].g = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#g");
			res[field].b = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#b");

			res[field].startPoint = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#startPoint");
			res[field].endPoint = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#endPoint");
			res[field].step = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#step");
			res[field].stepSize = getXMLFloat(hudXml, "GPS.GPSlines."..field.."#stepSize");
		end;
	end;
	return res;
end;


function GPS:saveCourse(self, slot, storeTable, noEventSend)
	if not self.GPSfirstrun then
		if GPS.Store == nil then
			GPS.Store = {};
		end;
		GPS.Store[slot] = {};
		if storeTable ~= nil then
			GPS.Store[slot] = storeTable;
		else
			GPS.Store[slot].lhdX0 = self.lhdX0;
			GPS.Store[slot].lhdZ0 = self.lhdZ0;
			GPS.Store[slot].lhX0 = self.lhX0;
			GPS.Store[slot].lhZ0 = self.lhZ0;
			GPS.Store[slot].GPSWidth = self.GPSWidth;
			GPS.Store[slot].GPS_LRoffset = self.GPS_LRoffset
			GPS.Store[slot].GPS_slotName = self.GPS_slotName;
		end;
		self.GPS_blinkTime = 4000;
		self.GPS_lastActionText = Steerable.GPS_TXT_SAVE	
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(GPS_SaveEvent:new(self, self.GPS_storeSlot, self.lhX0,self.lhZ0,self.lhdX0,self.lhdZ0,self.GPSWidth,self.GPS_LRoffset,self.GPS_slotName), nil, nil, self);
				-- print("GPS:saveCourse - g_server:broadcastEvent(GPS_SaveEvent:new(self = "..tostring(self)..", self.GPS_storeSlot = "..tostring(self.GPS_storeSlot))
			else
				g_client:getServerConnection():sendEvent(GPS_SaveEvent:new(self, self.GPS_storeSlot, self.lhX0,self.lhZ0,self.lhdX0,self.lhdZ0,self.GPSWidth,self.GPS_LRoffset,self.GPS_slotName));
				-- print("GPS:saveCourse - g_client:getServerConnection():sendEvent(GPS_SaveEvent:new(self = "..tostring(self)..", self.GPS_storeSlot = "..tostring(self.GPS_storeSlot))
			end;
		else -- we get a SaveEvent, so load the new course if this is in the current storeSlot (self.GPS_storeSlot) 
			GPS.GPSchangedSlot = slot;
		end;	
	end		
end;

function GPS:deleteCourse(self, slot, noEventSend)
	if GPS.Store == nil then
		GPS.Store = {};
	end;
	GPS.Store[slot] = nil;
	-- name -> update self.GPS_slotName
	if self.GPS_storeSlot == slot then	
		self.GPS_slotName = "";
	end;	
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(GPS_DeleteEvent:new(self, slot), nil, nil, self);
			-- print("GPS:deleteCourse - g_server:broadcastEvent(GPS_DeleteEvent:new(self = "..tostring(self)..", slot = "..tostring(self.GPS_storeSlot))
		else
			g_client:getServerConnection():sendEvent(GPS_DeleteEvent:new(self, slot));
			-- print("GPS:deleteCourse - g_client:getServerConnection():sendEvent(GPS_DeleteEvent:new(self = "..tostring(self)..", slot = "..tostring(self.GPS_storeSlot))
		end;
	else -- we get an deleteEvent, so change self.GPS_slotName
		GPS.GPSchangedSlot = slot;
	end;	
end;					

function GPS:loadCourse(self)
	if GPS.Store ~= nil then
		self.GPSfirstrun = false
		if GPS.Store[self.GPS_storeSlot] ~= nil then
			self.lhdX0 = GPS.Store[self.GPS_storeSlot].lhdX0;
			self.lhdZ0 = GPS.Store[self.GPS_storeSlot].lhdZ0;
			self.lhX0 = GPS.Store[self.GPS_storeSlot].lhX0;
			self.lhZ0 = GPS.Store[self.GPS_storeSlot].lhZ0;
			self.GPSWidth = GPS.Store[self.GPS_storeSlot].GPSWidth;
			self.GPS_LRoffset = GPS.Store[self.GPS_storeSlot].GPS_LRoffset
			if GPS.Store[self.GPS_storeSlot].GPS_slotName ~= nil then
				self.GPS_slotName = GPS.Store[self.GPS_storeSlot].GPS_slotName
			end;
			self.GPS_blinkTime = 2500;
			self.GPS_lastActionText = Steerable.GPS_TXT_LOAD
		end;
	end;	
end;					
					
-- name
function GPS:userInput(self)
	setTextColor(1,1,1,1);
	renderText(0.4, 0.9, 0.02, self.userInputMessage .. self.GPS_slotName);
end

function GPS:keyInput(self, unicode)
	if 31 < unicode and unicode < 127 then
		if self.GPS_slotName ~= nil then
			if self.GPS_slotName:len() <= 30 then
				self.GPS_slotName = self.GPS_slotName .. string.char(unicode)
			end;
		end;
	end;

	-- backspace
	if unicode == 8 then
		if self.GPS_slotName ~= nil then
			if self.GPS_slotName:len() >= 1 then
				self.GPS_slotName = self.GPS_slotName:sub(1, self.GPS_slotName:len() - 1)
			end;
		end;
	end;

	-- enter
	if unicode == 13 then
		GPS:handleUserInput(self)
	end;
end;

function GPS:handleUserInput(self)
	GPS:saveCourse(self, self.GPS_storeSlot);
	self.userInputActive = false;
	self.userInputMessage = nil;
end