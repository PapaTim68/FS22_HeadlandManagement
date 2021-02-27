--
-- Headland Management for LS 19
--
-- Martin Eller
-- Version 0.0.4.2
-- 
-- RidgeMarkerSwitching
--

headlandManagement = {}
headlandManagement.MOD_NAME = g_currentModName

headlandManagement.REDUCESPEED = 1
headlandManagement.RAISEIMPLEMENT = 2
headlandManagement.STOPGPS = 3

headlandManagement.isDedi = g_dedicatedServerInfo ~= nil

function headlandManagement.prerequisitesPresent(specializations)
  return true
end

function headlandManagement.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", headlandManagement)
 	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", headlandManagement)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", headlandManagement)
end

function headlandManagement:onLoad(savegame)
	local spec = self.spec_headlandManagement
	spec.dirtyFlag = self:getNextDirtyFlag()
	
	self.hlmNormSpeed = 20
	self.hlmTurnSpeed = 5

	self.hlmActStep = 0
	self.hlmMaxStep = 4
	
	self.hlmIsActive = false
	self.hlmAction = {}
	self.hlmAction[0] =false
	
	self.hlmModSpeedControlFound = false
	self.hlmUseSpeedControl = true
	
	self.hlmUseRaiseImplement = true
	self.hlmImplementsTable = {}
	self.hlmUseTurnPlow = true
	
	self.hlmUseRidgeMarker = true
	self.hlmRidgeMarkerState = 0
	
	self.hlmModGuidanceSteeringFound = false
	self.hlmUseGuidanceSteering = true	
	self.hlmGSStatus = false
end

function headlandManagement:onPostLoad(savegame)
	local spec = self.spec_headlandManagement
	if spec == nil then return end

	if savegame ~= nil then	
		local xmlFile = savegame.xmlFile
		local key = savegame.key .. ".headlandManagement"
	
		self.hlmTurnSpeed = Utils.getNoNil(getXMLFloat(xmlFile, key.."#turnSpeed"), self.hlmTurnSpeed)
		self.hlmIsActive = Utils.getNoNil(getXMLBool(xmlFile, key.."#isActive"), self.hlmIsActive)
		self.hlmUseSpeedControl = Utils.getNoNil(getXMLBool(xmlFile, key.."#useSpeedControl"), self.hlmUseSpeedControl)
		self.hlmUseRaiseImplement = Utils.getNoNil(getXMLBool(xmlFile, key.."#useRaiseImplement"), self.hlmUseRaiseImplement)
		self.hlmUseGuidanceSteering = Utils.getNoNil(getXMLBool(xmlFile, key.."#useGuidanceSteering"), self.hlmUseGuidanceSteering)
		self.hlmUseTurnPlow = Utils.getNoNil(getXMLBool(xmlFile, key.."#turnPlow"), self.hlmUseTurnPlow)
		self.hlmUseRidgeMarker = Utils.getNoNil(getXMLBool(xmlFile, key.."#switchRidge"), self.hlmUseRidgeMarker)
		print("HeadlandManagement: Loaded data for "..self:getName())
	end
	
	-- Check if Mod SpeedControl exists
	if SpeedControl ~= nil and SpeedControl.onInputAction ~= nil then 
		self.hlmModSpeedControlFound = true 
		self.hlmUseSpeedControl = true
		self.hlmTurnSpeed = 1 --SpeedControl Mode 1
		self.hlmNormSpeed = 2 --SpeedControl Mode 2
	end
	
	-- Check if Mod GuidanceSteering exists
	local gsSpec = self.spec_globalPositioningSystem
	if gsSpec ~= nil then
		self.hlmModGuidanceSteeringFound = true
	end

	-- Set order of management actions
	self.hlmAction[headlandManagement.REDUCESPEED] = self.hlmModSpeedControlFound and self.hlmUseSpeedControl
	self.hlmAction[headlandManagement.RAISEIMPLEMENT] = self.hlmUseRaiseImplement
	self.hlmAction[headlandManagement.STOPGPS] = self.hlmModGuidanceSteeringFound and self.hlmUseGuidanceSteering
end

function headlandManagement:saveToXMLFile(xmlFile, key)
	setXMLFloat(xmlFile, key.."#turnSpeed", self.hlmTurnSpeed)
	setXMLBool(xmlFile, key.."#isActive", self.hlmIsActive)
	setXMLBool(xmlFile, key.."#useSpeedControl", self.hlmUseSpeedControl)
	setXMLBool(xmlFile, key.."#useRaiseImplement", self.hlmUseRaiseImplement)
	setXMLBool(xmlFile, key.."#useGuidanceSteering", self.hlmUseGuidanceSteering)
	setXMLBool(xmlFile, key.."#turnPlow", self.hlmUseTurnPlow)
	setXMLBool(xmlFile, key.."#switchRidge", self.hlmUseRidgeMarker)
end

function headlandManagement:onReadStream(streamId, connection)
	self.hlmTurnSpeed = streamReadFloat32(streamId)
	self.hlmIsActive = streamReadBool(streamId)
	self.hlmUseSpeedControl = streamReadBool(streamId)
	self.hlmUseRaiseImplement = streamReadBool(streamId)
	self.hlmUseGuidanceSteering = streamReadBool(streamId)
	self.hlmUseTurnPlow = streamReadBool(streamId)
end

function headlandManagement:onWriteStream(streamId, connection)
	streamWriteFloat32(streamId, self.hlmTurnSpeed)
	streamWriteBool(streamId, self.hlmIsActive)
	streamWriteBool(streamId, self.hlmUseSpeedControl)
	streamWriteBool(streamId, self.hlmUseRaiseImplement)
	streamWriteBool(streamId, self.hlmUseGuidanceSteering)
	streamWriteBool(streamId, self.hlmUseTurnPlow)
end
	
function headlandManagement:onReadUpdateStream(streamId, timestamp, connection)
	if not connection:getIsServer() then
		if streamReadBool(streamId) then
			self.hlmTurnSpeed = streamReadFloat32(streamId)
			self.hlmActStep = streamReadInt8(streamId)
			self.hlmIsActive = streamReadBool(streamId)
			self.hlmUseSpeedControl = streamReadBool(streamId)
			self.hlmUseRaiseImplement = streamReadBool(streamId)
			self.hlmUseGuidanceSteering = streamReadBool(streamId)
			self.hlmUseTurnPlow = streamReadBool(streamId)
		end;
	end
end

function headlandManagement:onWriteUpdateStream(streamId, connection, dirtyMask)
	if connection:getIsServer() then
		local spec = self.spec_headlandManagement
		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, self.hlmTurnSpeed)
			streamWriteInt8(streamId, self.hlmActStep)
			streamWriteBool(streamId, self.hlmIsActive)
			streamWriteBool(streamId, self.hlmUseSpeedControl)
			streamWriteBool(streamId, self.hlmUseRaiseImplement)
			streamWriteBool(streamId, self.hlmUseGuidanceSteering)
			streamWriteBool(streamId, self.hlmUseTurnPlow)
		end
	end
end
	
function headlandManagement:onRegisterActionEvents(isActiveForInput)
	if self.isClient then
		headlandManagement.actionEvents = {} 
		if self:getIsActiveForInput(true) then 
			local actionEventId;
			_, actionEventId = self:addActionEvent(headlandManagement.actionEvents, 'HLM_TOGGLESTATE', self, headlandManagement.TOGGLESTATE, false, true, false, true, nil)
			_, actionEventId = self:addActionEvent(headlandManagement.actionEvents, 'HLM_SWITCHON', self, headlandManagement.TOGGLESTATE, false, true, false, true, nil)
			_, actionEventId = self:addActionEvent(headlandManagement.actionEvents, 'HLM_SWITCHOFF', self, headlandManagement.TOGGLESTATE, false, true, false, true, nil)
		end		
	end
end

function headlandManagement:TOGGLESTATE(actionName, keyStatus, arg3, arg4, arg5)
	local spec = self.spec_headlandManagement
	-- anschalten nur wenn inaktiv
	if not self.hlmIsActive and (actionName == "HLM_SWITCHON" or actionName == "HLM_TOGGLESTATE") then
		self.hlmIsActive = true
	-- abschalten nur wenn aktiv
	elseif self.hlmIsActive and (actionName == "HLM_SWITCHOFF" or actionName == "HLM_TOGGLESTATE") and self.hlmActStep == self.hlmMaxStep then
		self.hlmActStep = -self.hlmActStep
	end
	self:raiseDirtyFlags(spec.dirtyFlag)
end

function headlandManagement:onUpdate(dt)
	if self:getIsActive() and self.hlmIsActive and self.hlmActStep<self.hlmMaxStep then
		local spec = self.spec_headlandManagement
		if self.hlmAction[math.abs(self.hlmActStep)] and not headlandManagement.isDedi then		
			-- Activation
			if self.hlmActStep == headlandManagement.REDUCESPEED and self.hlmAction[headlandManagement.REDUCESPEED] then headlandManagement:reduceSpeed(self, true); end
			if self.hlmActStep == headlandManagement.RAISEIMPLEMENT and self.hlmAction[headlandManagement.RAISEIMPLEMENT] then headlandManagement:raiseImplements(self, true, self.hlmUseTurnPlow); end
			if self.hlmActStep == headlandManagement.STOPGPS and self.hlmAction[headlandManagement.STOPGPS] then headlandManagement:stopGPS(self, true); end
			-- Deactivation
			if self.hlmActStep == -headlandManagement.STOPGPS and self.hlmAction[headlandManagement.STOPGPS] then headlandManagement:stopGPS(self, false); end
			if self.hlmActStep == -headlandManagement.RAISEIMPLEMENT and self.hlmAction[headlandManagement.RAISEIMPLEMENT] then headlandManagement:raiseImplements(self, false, false); end
			if self.hlmActStep == -headlandManagement.REDUCESPEED and self.hlmAction[headlandManagement.REDUCESPEED] then headlandManagement:reduceSpeed(self, false); end		
		end
		self.hlmActStep = self.hlmActStep + 1
		if self.hlmActStep == 0 then 
			self.hlmIsActive = false
			self:raiseDirtyFlags(spec.dirtyFlag)
		end	
	end
end

function headlandManagement:onDraw(dt)
	if self.hlmIsActive then 
		g_currentMission:addExtraPrintText(g_i18n:getText("text_HLM_isActive"))
	end
end
	
function headlandManagement:reduceSpeed(self, enable)	
	if enable then
		if self.hlmUseSpeedControl then
			SpeedControl.onInputAction(self, "SPEEDCONTROL_SPEED"..tostring(self.hlmTurnSpeed), true, false, false)
		else
			self.hlmNormSpeed = self:getCruiseControlSpeed()
			self:setCruiseControlMaxSpeed(self.hlmTurnSpeed)
		end
	else
		if self.hlmUseSpeedControl then
			SpeedControl.onInputAction(self, "SPEEDCONTROL_SPEED"..tostring(self.hlmNormSpeed), true, false, false)
		else
			self:setCruiseControlMaxSpeed(self.hlmNormSpeed)
		end
	end
end

function headlandManagement:raiseImplements(self, raise, turnPlow)
    local jointSpec = self.spec_attacherJoints
    for _,attachedImplement in pairs(jointSpec.attachedImplements) do
    	local index = attachedImplement.jointDescIndex
    	local actImplement = attachedImplement.object
		-- raise or lower implement and turn plow
		if actImplement ~= nil and actImplement.getAllowsLowering ~= nil then
			if actImplement:getAllowsLowering() or actImplement.spec_pickup ~= nil or actImplement.spec_foldable ~= nil then
				if raise then
					local lowered = actImplement:getIsLowered()
					self.hlmImplementsTable[index] = lowered
					if lowered and actImplement.setLoweredAll ~= nil then 
						actImplement:setLoweredAll(false, index)
						lowered = actImplement:getIsLowered()
		 			end
		 			if lowered and actImplement.setLowered ~= nil then
		 				actImplement:setLowered(false)
		 				lowered = actImplement:getIsLowered()
		 			end
		 			if lowered and self.setJointMoveDown ~= nil then
		 				self:setJointMoveDown(index, false)
		 				lowered = actImplement:getIsLowered()
		 			end
		 			if lowered and actImplement.spec_attacherJointControlPlow ~= nil then
		 				local spec = actImplement.spec_attacherJointControl
		 				spec.heightTargetAlpha = spec.jointDesc.upperAlpha
				        actImplement:requestActionEventUpdate()
				    	lowered = actImplement:getIsLowered()
				    end
				    if lowered and actImplement.spec_attacherJointControlCutter~= nil then
		 				local spec = actImplement.spec_attacherJointControl
		 				spec.heightTargetAlpha = spec.jointDesc.upperAlpha
				        actImplement:requestActionEventUpdate()
				    	lowered = actImplement:getIsLowered()
				    end
				    if lowered and actImplement.spec_attacherJointControlCultivator~= nil then
		 				local spec = actImplement.spec_attacherJointControl
		 				spec.heightTargetAlpha = spec.jointDesc.upperAlpha
				        actImplement:requestActionEventUpdate()
				    	lowered = actImplement:getIsLowered()
				    end
		 			local plowSpec = actImplement.spec_plow
		 			if plowSpec ~= nil and turnPlow and self.hlmImplementsTable[index] then 
						if plowSpec.rotationPart.turnAnimation ~= nil then
					        if actImplement:getIsPlowRotationAllowed() then
					            actImplement:setRotationMax(not plowSpec.rotationMax)
					        end
					    end
		 			end
		 		else
		 			local wasLowered = self.hlmImplementsTable[index]
		 			local lowered
		 			if wasLowered and actImplement.setLoweredAll ~= nil then
		 				actImplement:setLoweredAll(true, index)
		 				lowered = actImplement:getIsLowered()
		 			end
		 			if wasLowered and not lowered and actImplement.setLowered ~= nil then
		 				actImplement:setLowered(true)
		 				lowered = actImplement:getIsLowered()
		 			end
		 			if wasLowered and not lowered and self.setJointMoveDown ~= nil then
		 				self:setJointMoveDown(index, true)
		 				lowered = actImplement:getIsLowered()
		 			end
		 			if wasLowered and not lowered and actImplement.spec_attacherJointControlPlow ~= nil then
		 				local spec = actImplement.spec_attacherJointControl
		 				spec.heightTargetAlpha = spec.jointDesc.lowerAlpha
				        actImplement:requestActionEventUpdate()
				    	lowered = actImplement:getIsLowered()
				    end
				    if wasLowered and not lowered and actImplement.spec_attacherJointControlCutter ~= nil then
		 				local spec = actImplement.spec_attacherJointControl
		 				spec.heightTargetAlpha = spec.jointDesc.lowerAlpha
				        actImplement:requestActionEventUpdate()
				    	lowered = actImplement:getIsLowered()
				    end
				    if wasLowered and not lowered and actImplement.spec_attacherJointControlCultivator ~= nil then
		 				local spec = actImplement.spec_attacherJointControl
		 				spec.heightTargetAlpha = spec.jointDesc.lowerAlpha
				        actImplement:requestActionEventUpdate()
				    	lowered = actImplement:getIsLowered()
				    end
		 		end	
		 	end
		end
		-- switch ridge marker
		if actImplement ~= nil and actImplement.spec_ridgeMarker ~= nil then
			local specRM = actImplement.spec_ridgeMarker
			if raise then
				self.hlmRidgeMarkerState = specRM.ridgeMarkerState
			else
				if self.hlmRidgeMarkerState == 1 then 
					self.hlmRidgeMarkerState = 2 
				elseif self.hlmRidgeMarkerState == 2 then
		  			self.hlmRidgeMarkerState = 1
				end
				actImplement:setRidgeMarkerState(self.hlmRidgeMarkerState)
			end
		end
	end
end

function headlandManagement:stopGPS(self, enable)
	local gsSpec = self.spec_globalPositioningSystem
	if self.onSteeringStateChanged == nil then return; end
	if enable then
		local gpsEnabled = (gsSpec.lastInputValues ~= nil and gsSpec.lastInputValues.guidanceSteeringIsActive)
		if gpsEnabled then
			self.hlmGSStatus = true
			gsSpec.lastInputValues.guidanceSteeringIsActive = false
			self:onSteeringStateChanged(false)
		else
			self.hlmGSStatus = false
		end
	else
		local gpsEnabled = self.hlmGSStatus	
		if gpsEnabled then
			gsSpec.lastInputValues.guidanceSteeringIsActive = true
			self:onSteeringStateChanged(true)
		end
	end
end
