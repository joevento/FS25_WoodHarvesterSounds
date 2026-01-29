playerTrigger = {};
playerTrigger.dir = g_currentModDirectory;

function playerTrigger:loadMap(name)
	self.wls = {}
	if g_currentMission.wls == nil then
		g_currentMission.wls = {}
	end
	self.wls = {}
	self.wls.root = Utils.indexToObject(self.components,"0>");
	self.wls.logs = {}
	self.wls.tempDist = {}
	self.wls.tempDistGround = {}
	self.wls.logsInfo = ""
	self.wls.logsInfo2 = ""
	self.wls.logsInfo3 = ""
	self.wls.playSound = false
	self.wls.timer = 0
	self.wls.log = nil
	self.wls.log2 = nil
	self.wls.logCenter = nil
	self.wls.logCenter2 = nil
	self.wls.logTop = nil
	self.wls.logBottom = nil
	self.wls.debug = false
	self.wls.isPlaying = false
	local dir = g_modsDirectory..'/WoodLogsSound/'
	self.wls.trigger = loadI3DFile(Utils.getFilename("trigger.i3d", dir))
	local triggerId = getChildAt(self.wls.trigger,0)
	self.wls.triggerPlayer = triggerId
	
	if g_client ~= nil  then
		if g_currentMission.wls.samplesLogs == nil then
			g_currentMission.wls.samplesLogs = {}
			g_currentMission.wls.samplesLogs[1] = {createSample("sampleLogs01"),1}
			g_currentMission.wls.samplesLogs[2] = {createSample("sampleLogs02"),0.8}
			for i,sample in pairs(g_currentMission.wls.samplesLogs) do
				loadSample(g_currentMission.wls.samplesLogs[i][1],  Utils.getFilename("logs0"..i..".wav", WoodLogsSound.Dir..'Sounds/'), false);
				setSamplePitch(g_currentMission.wls.samplesLogs[i][1],g_currentMission.wls.samplesLogs[i][2])
			end
			g_currentMission.wls.samplesGround = {}
			g_currentMission.wls.samplesGround[1] = {createSample("sampleGround01"),1}
			g_currentMission.wls.samplesGround[2] = {createSample("sampleGround02"),0.7}
			g_currentMission.wls.samplesGround[3] = {createSample("sampleGround03"),1}
			for i,sample in pairs(g_currentMission.wls.samplesGround) do
				loadSample(g_currentMission.wls.samplesGround[i][1],  Utils.getFilename("ground0"..i..".wav", WoodLogsSound.Dir..'Sounds/'), false);
				setSamplePitch(g_currentMission.wls.samplesGround[i][1],g_currentMission.wls.samplesGround[i][2])
			end
			g_currentMission.wls.samplesFall= {}
			g_currentMission.wls.samplesFall[1] = {createSample("samplesFall01"),1}
			for i,sample in pairs(g_currentMission.wls.samplesFall) do
				loadSample(g_currentMission.wls.samplesFall[i][1],  Utils.getFilename("fall0"..i..".wav", WoodLogsSound.Dir..'Sounds/'), false);
				setSamplePitch(g_currentMission.wls.samplesFall[i][1],g_currentMission.wls.samplesFall[i][2])
			end
			self.wls.isPlaying = false
		end
	end
end;

function playerTrigger:keyEvent(unicode, sym, modifier, isDown)
end;

function playerTrigger:update(dt)
	if g_currentMission.player ~= nil then
		if g_currentMission.player.wlsTrigger == nil then
			addTrigger(self.wls.triggerPlayer, "triggerCallbackPlayer", self);
			link(g_currentMission.player.rootNode, self.wls.triggerPlayer)
			g_currentMission.player.wlsTrigger = true
		end
	end
	if g_currentMission.controlPlayer then
		if Input.isKeyPressed(Input.KEY_t) then	
			--self.wls.debug = not self.wls.debug
		end;
		self.wls.timer = self.wls.timer + dt
		if self.wls.timer >= 200 then
			self.wls.timer = 0
			self.wls.logsInfo = ""
			self.wls.logsInfo2 = ""
			self.wls.logsInfo3 = ""
			for i,v in pairs(self.wls.logs) do
				if entityExists(v) then
					local x,y,z = getWorldTranslation(v)
					local nx,ny,nz = localDirectionToWorld(v, 0,1,0);
					local lenBelow, lenAbove = getSplitShapePlaneExtents(v, x,y,z,nx,ny,nz);
					--self.wls.logsInfo = self.wls.logsInfo .. 'Log '..i..' : '..v..' bel-'..string.format("%.3f",lenBelow)..' abo-'..string.format("%.3f",lenAbove)..'\n'
					local diffGround = 0
					if getChild(v,'logCenter') == 0 then
						local x,y,z = getWorldTranslation(v)
						local nx,ny,nz = localDirectionToWorld(v, 0,1,0);
						local lenBelow, lenAbove = getSplitShapePlaneExtents(v, x,y,z,nx,ny,nz);
						local sizeX, sizeY, sizeZ = getSplitShapeStats(v)
						local logCenter = createTransformGroup("logCenter")
						link(v, logCenter)
						setTranslation(logCenter, 0,-lenBelow+(sizeX/2),0)
						self.wls.log = v
						self.wls.logCenter = logCenter
					else
						local logCenter = getChild(v,'logCenter')
						self.wls.log = v
						self.wls.logCenter = logCenter
					end
					if getChild(v,'logTop') == 0 then
						local x,y,z = getWorldTranslation(v)
						local nx,ny,nz = localDirectionToWorld(v, 0,1,0);
						local lenBelow, lenAbove = getSplitShapePlaneExtents(v, x,y,z,nx,ny,nz);
						local sizeX, sizeY, sizeZ = getSplitShapeStats(v)
						local logTop = createTransformGroup("logTop")
						link(v, logTop)
						setTranslation(logTop, 0,lenAbove,0)
						self.wls.logTop = logTop
					else
						local logTop = getChild(v,'logTop')
						self.wls.logTop = logTop
					end
					if getChild(v,'logBottom') == 0 then
						local x,y,z = getWorldTranslation(v)
						local nx,ny,nz = localDirectionToWorld(v, 0,1,0);
						local lenBelow, lenAbove = getSplitShapePlaneExtents(v, x,y,z,nx,ny,nz);
						local sizeX, sizeY, sizeZ = getSplitShapeStats(v)
						local logBottom = createTransformGroup("logBottom")
						link(v, logBottom)
						setTranslation(logBottom, 0,-lenBelow,0)
						self.wls.logBottom = logBottom
					else
						local logBottom = getChild(v,'logBottom')
						self.wls.logBottom = logBottom
					end
					for j,vv in pairs(self.wls.logs) do
						local diff = 0
						if entityExists(vv) then
							if v ~= vv then
								if getChild(vv,'logCenter') == 0 then
									local x,y,z = getWorldTranslation(vv)
									local nx,ny,nz = localDirectionToWorld(vv, 0,1,0);
									local lenBelow, lenAbove = getSplitShapePlaneExtents(vv, x,y,z,nx,ny,nz);
									local sizeX, sizeY, sizeZ = getSplitShapeStats(vv)
									local logCenter = createTransformGroup("logCenter")
									link(vv, logCenter)
									setTranslation(logCenter, 0,-lenBelow+(sizeX/2),0)
									self.wls.log2 = vv
									self.wls.logCenter2 = logCenter
								else
									local logCenter = getChild(vv,'logCenter')
									self.wls.logCenter2 = logCenter
								end
								local a,b,c = getWorldTranslation(self.wls.logCenter)
								local x,y,z = getWorldTranslation(self.wls.logCenter2)
								local dist = Utils.vector3Length(a - x, b - y, c - z)
								if self.wls.tempDist[v] == nil then
									self.wls.tempDist[v] = {}
									self.wls.tempDist[v][vv] = dist
								elseif self.wls.tempDist[v][vv] == nil then
									self.wls.tempDist[v][vv] = dist
								else
									diff = self.wls.tempDist[v][vv] - dist
									if diff > 0.05 and dist < 0.7 then
										if g_client ~= nil  then
											if WoodLogsSound.checkIsInRange(self,self.wls.logCenter,nil) then
												if not WoodLogsSound.checkPlayingSamples(self,g_currentMission.wls.samplesLogs) then
													self:playSound(true)
												end
											end
										end
										self.wls.playSound = true
									else
										self.wls.playSound = false
									end
									self.wls.tempDist[v][vv] = dist
								end
								--self.wls.logsInfo2 = self.wls.logsInfo2 .. 'Log '..v..' - '..vv..' - Dist: '..string.format("%.3f",dist)..' - Diff: '..string.format("%.3f",diff)..'PlaySound - '..tostring(self.wls.playSound)..'\n'
							end
						else
							self.wls.logs[vv] = nil;
							self.wls.tempDist[vv] = nil
						end
					end
					local x,y,z = getWorldTranslation(self.wls.logTop)
					local terrainY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,x,y,z)
					local distanceGround = y - terrainY
					local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(v)
					if self.wls.tempDistGround[v] == nil then
						self.wls.tempDistGround[v] = distanceGround
					else
						diffGround = self.wls.tempDistGround[v] - distanceGround
						self.wls.tempDistGround[v] = distanceGround
						if diffGround > 1 and numAttachments > 5 and distanceGround > 10 then
							if g_client ~= nil  then
								if WoodLogsSound.checkIsInRange(self,self.wls.logCenter,self.wls.logBottom) then
									if not WoodLogsSound.checkPlayingSamples(self,g_currentMission.wls.samplesFall) then
										self:playSoundFall(true)
									end
								end
							end
							self.wls.playSound = true
						elseif distanceGround < 0.35 and diffGround > 0.05 then
							if g_client ~= nil  then
								if WoodLogsSound.checkIsInRange(self,self.wls.logCenter,self.wls.logBottom) then
									if not WoodLogsSound.checkPlayingSamples(self,g_currentMission.wls.samplesGround) then
										self:playSoundGround(true)
									end
								end
							end
							self.wls.playSound = true
						else
							self.wls.playSound = false
						end
					end
					--self.wls.logsInfo2 = self.wls.logsInfo2 .. 'Log '..v..' - distGround: '..string.format("%.3f",distanceGround)..' - diffGround: '..string.format("%.3f",diffGround)..'PlaySound - '..tostring(self.wls.playSound)..' - '..numAttachments..'\n'
				else
					self.wls.logs[v] = nil;
					self.wls.tempDist[v] = nil
					self.wls.tempDistGround[v] = nil
				end
			end
		end
	else
		self.wls.logsInfo = ""
		self.wls.logsInfo2 = ""
		self.wls.logsInfo3 = ""
		self.wls.logs = {}
	end
end;

function playerTrigger:triggerCallbackPlayer(triggerId,otherId,onEnter,onLeave,onStay)
	if onEnter then
		local splitType = SplitUtil.splitTypes[getSplitType(otherId)];
		if splitType ~= nil and self.wls.logs[otherId] == nil then
			if entityExists(otherId) and getRigidBodyType(otherId) == 'Dynamic' then
				self.wls.logs[otherId] = otherId;
			end
		end
	elseif onLeave then
		local splitType = SplitUtil.splitTypes[getSplitType(otherId)];
		if splitType ~= nil and self.wls.logs[otherId] == otherId then
			if entityExists(otherId) and getRigidBodyType(otherId) == 'Dynamic' then
				self.wls.logs[otherId] = nil;
				self.wls.tempDist[otherId] = nil
				self.wls.tempDistGround[otherId] = nil
			end
		end
	end
end;
function playerTrigger:playSound(isPlaying)
	if g_currentMission.wls.samplesLogs ~= nil then
		if isPlaying then
			local number = math.random(1,2)
			local pitch = getSamplePitch(g_currentMission.wls.samplesLogs[number][1])
            playSample(g_currentMission.wls.samplesLogs[number][1], 1, 1, 0);
			self.wls.isPlaying = true
		end
	end
end;
function playerTrigger:playSoundGround(isPlaying)
	if g_currentMission.wls.samplesGround ~= nil then
		if isPlaying then
			local number = math.random(2,2)
			local pitch = getSamplePitch(g_currentMission.wls.samplesGround[number][1])
            playSample(g_currentMission.wls.samplesGround[number][1], 1, 1, 0);
			self.wls.isPlaying = true
		end
	end
end;
function playerTrigger:playSoundFall(isPlaying)
	if g_currentMission.wls.samplesFall ~= nil then
		if isPlaying then
			local number = math.random(1,1)
			local pitch = getSamplePitch(g_currentMission.wls.samplesFall[number][1])
            playSample(g_currentMission.wls.samplesFall[number][1], 1, 1, 0);
			self.wls.isPlaying = true
		end
	end
end;
function playerTrigger:checkPlayingSamples(samples)
	local isPlaying = false
	for i,sample in pairs(samples) do
		if isSamplePlaying(sample[1]) then
			isPlaying = true
		end
	end
	return isPlaying
end;
function playerTrigger:checkIsInRange(shape,shape2)
	local inRange = false
	local target
	if g_currentMission.controlPlayer and g_currentMission.player ~= nil then
		target = g_currentMission.player.rootNode
	elseif g_currentMission.controlledVehicle ~= nil then
		target = g_currentMission.controlledVehicle.rootNode
	end
	if target ~= nil and shape ~= nil and entityExists(shape) then
		local x,y,z = getWorldTranslation(target)
		local a,b,c = getWorldTranslation(shape)
		local distance = Utils.vector3Length(x-a, y-b, z-c);
		if distance < 20 then
			inRange = true
		end
		if shape2 ~= nil and entityExists(shape2) then
			local a,b,c = getWorldTranslation(shape2)
			local distance = Utils.vector3Length(x-a, y-b, z-c);
			if distance < 20 then
				inRange = true
			end
		end
	end
	return inRange
end;

function playerTrigger:draw()
	if g_client ~= nil  then
		if self.wls.debug == true then
			setTextBold(false);
			setTextAlignment(RenderText.ALIGN_LEFT);
			setTextColor(0.6307, 0.6307, 0.6307, 1);
			renderText(0.55, 0.75, 0.013, self.wls.logsInfo);
			renderText(0.69, 0.75, 0.013, self.wls.logsInfo2);
			renderText(0.69, 0.85, 0.013, self.wls.logsInfo3);
			for i,v in pairs(self.wls.logs) do
				if entityExists(v) then
					if getChild(v,'logCenter') ~= 0 then
						local logCenter = getChild(v,'logCenter')
						if logCenter ~= 0 and logCenter ~= nil then
							local x,y,z = getWorldTranslation(logCenter)
							local nx, ny, nz = localDirectionToWorld(v, 2, 0, 0)
							local yx, yy, yz = localDirectionToWorld(v, 0, 2, 0)
							local zx, zy, zz = localDirectionToWorld(v, 0, 0, 2)
							drawDebugLine(x,y,z, 1, 0, 0, x + nx, y + ny, z + nz, 1, 0, 0);
							drawDebugLine(x,y,z, 0, 1, 0, x + yx, y + yy, z + yz, 0, 1, 0);
							drawDebugLine(x,y,z, 0, 0, 1, x + zx, y + zy, z + zz, 0, 0, 1);
						end
					end
					if getChild(v,'logTop') ~= 0 then
						local logTop = getChild(v,'logTop')
						if logTop ~= 0 and logTop ~= nil then
							local x,y,z = getWorldTranslation(logTop)
							local nx, ny, nz = localDirectionToWorld(v, 2, 0, 0)
							local yx, yy, yz = localDirectionToWorld(v, 0, 2, 0)
							local zx, zy, zz = localDirectionToWorld(v, 0, 0, 2)
							drawDebugLine(x,y,z, 1, 0, 0, x + nx, y + ny, z + nz, 1, 0, 0);
							drawDebugLine(x,y,z, 0, 1, 0, x + yx, y + yy, z + yz, 0, 1, 0);
							drawDebugLine(x,y,z, 0, 0, 1, x + zx, y + zy, z + zz, 0, 0, 1);
						end
					end
					if getChild(v,'logBottom') ~= 0 then
						local logBottom = getChild(v,'logBottom')
						if logBottom ~= 0 and logBottom ~= nil then
							local x,y,z = getWorldTranslation(logBottom)
							local nx, ny, nz = localDirectionToWorld(v, 2, 0, 0)
							local yx, yy, yz = localDirectionToWorld(v, 0, 2, 0)
							local zx, zy, zz = localDirectionToWorld(v, 0, 0, 2)
							drawDebugLine(x,y,z, 1, 0, 0, x + nx, y + ny, z + nz, 1, 0, 0);
							drawDebugLine(x,y,z, 0, 1, 0, x + yx, y + yy, z + yz, 0, 1, 0);
							drawDebugLine(x,y,z, 0, 0, 1, x + zx, y + zy, z + zz, 0, 0, 1);
						end
					end
					local x,y,z = getWorldTranslation(v)
					local nx, ny, nz = localDirectionToWorld(v, 5, 0, 0)
					local yx, yy, yz = localDirectionToWorld(v, 0, 5, 0)
					local zx, zy, zz = localDirectionToWorld(v, 0, 0, 5)
					drawDebugLine(x,y,z, 1, 0, 0, x + nx, y + ny, z + nz, 1, 0, 0);
					drawDebugLine(x,y,z, 0, 1, 0, x + yx, y + yy, z + yz, 0, 1, 0);
					drawDebugLine(x,y,z, 0, 0, 1, x + zx, y + zy, z + zz, 0, 0, 1);
				end
			end
		end
	end;
end;

function playerTrigger:deleteMap()
end;

function playerTrigger:mouseEvent(posX, posY, isDown, isUp, button)
end;
addModEventListener(playerTrigger);