function WoodHarvesterSound.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function WoodHarvesterSound.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", WoodHarvesterSound)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", WoodHarvesterSound)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", WoodHarvesterSound)
	SpecializationUtil.registerEventListener(vehicleType, "onPostCut", WoodHarvesterSound)
end

function WoodHarvesterSound:onPostCut(shape, length, diameter, isBelowMinimum)
	local spec = self.spec_woodHarvester
	if spec.lastSplitShapes ~= nil then
		local wasFelled = getUserAttribute(shape, "whs_hasFelled")
		if wasFelled then
			for _, newShape in pairs(spec.lastSplitShapes) do
				if entityExists(newShape) then
					setUserAttribute(newShape, "whs_hasFelled", true)
				end
			end
		end
	end
end

function WoodHarvesterSound:onLoad(savegame)
	self.whs = {}
	if g_currentMission.whs == nil then
		g_currentMission.whs = {}
	end

	if g_currentMission.whs.samplesLogs == nil then
		g_currentMission.whs.samplesLogs = {}
	end
	if g_currentMission.whs.samplesGround == nil then
		g_currentMission.whs.samplesGround = {}
	end
	if g_currentMission.whs.samplesFall == nil then
		g_currentMission.whs.samplesFall = {}
	end

	self.whs.root = self.rootNode
	self.whs.logs = {}
	self.whs.logsInfo = ""
	self.whs.logsInfo2 = ""
	self.whs.logsInfo3 = ""
	self.whs.timer = 0
	self.whs.debug = false
	self.whs.searchRadius = 1000

	if self.isClient then
		if #g_currentMission.whs.samplesLogs == 0 then
			local modDir = WoodHarvesterSound.modDirectory

			local function loadDirect(path, name)
				local fileName = Utils.getFilename(path, modDir)
				local sample = createSample(name)
				if loadSample(sample, fileName, false) then
					return sample
				end
				return nil
			end

			-- Load Log Collision Samples
			table.insert(g_currentMission.whs.samplesLogs, loadDirect("Sounds/logs01.wav", "WHS_log01"))
			table.insert(g_currentMission.whs.samplesLogs, loadDirect("Sounds/logs02.wav", "WHS_log02"))

			-- Load Ground Collision Samples
			table.insert(g_currentMission.whs.samplesGround, loadDirect("Sounds/ground01.wav", "WHS_ground01"))
			table.insert(g_currentMission.whs.samplesGround, loadDirect("Sounds/ground02.wav", "WHS_ground02"))
			table.insert(g_currentMission.whs.samplesGround, loadDirect("Sounds/ground03.wav", "WHS_ground03"))

			-- Load Tree Fall Samples
			table.insert(g_currentMission.whs.samplesFall, loadDirect("Sounds/fall01.wav", "WHS_fall01"))
		end
	end
end

function WoodHarvesterSound:onUpdate(dt)
	if self:getIsActive() then
		if self.whs.lastAngVel == nil then
			self.whs.lastAngVel = {}
		end

		self.whs.timer = self.whs.timer + dt
		if self.whs.timer >= 100 then
			self.whs.timer = 0

			local px, py, pz = getWorldTranslation(self.whs.root)
			self.whs.currentScanFound = {}

			local mask = 2048 + 262144 + 16777216

			if self.collisionTestCallback == nil then
				self.collisionTestCallback = WoodHarvesterSound.collisionTestCallback
			end

			overlapSphere(px, py, pz, self.whs.searchRadius, "collisionTestCallback", self, mask, true, false, true,
				false)

			if next(self.whs.currentScanFound) ~= nil then
				for logId, _ in pairs(self.whs.logs) do
					if not self.whs.currentScanFound[logId] then
						self.whs.logs[logId] = nil
					end
				end
			end

			WoodHarvesterSound.updatePlayingState(self, g_currentMission.whs.samplesGround, "Ground")
			WoodHarvesterSound.updatePlayingState(self, g_currentMission.whs.samplesFall, "Fall")
			WoodHarvesterSound.updatePlayingState(self, g_currentMission.whs.samplesLogs, "Logs")

			for logId, v in pairs(self.whs.logs) do
				if v ~= nil and entityExists(v) then
					local isAttached = (self.spec_woodHarvester.attachedSplitShape == v)
					local vx, vy, vz = getLinearVelocity(v)
					local velocity = MathUtil.vector3Length(vx, vy, vz)

					if velocity > 0.1 then
						local comX, comY, comZ = getCenterOfMass(v)
						local wcomX, wcomY, wcomZ = localToWorld(v, comX, comY, comZ)
						local x, y, z = getWorldTranslation(v)
						local terrainY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wcomX, wcomY, wcomZ)
						local comDistToGround = wcomY - terrainY

						local rotX, rotY, rotZ = getAngularVelocity(v)
						local angVelocity = MathUtil.vector3Length(rotX, rotY, rotZ)

						local lastAV = self.whs.lastAngVel[v] or 0
						self.whs.lastAngVel[v] = angVelocity

						-- Ground Impact
						if not isAttached and ((comDistToGround < 0.5 and velocity > 0.125) or (comDistToGround < 0.75 and angVelocity > 0.5)) then
							if WoodHarvesterSound.checkIsInRange(self, v) then
								if not self.whs.isGroundPlaying then
									WoodHarvesterSound.playSound(self, g_currentMission.whs.samplesGround, v, "Ground")
								end
							end
						end

						-- Tree Falling
						if timeToGround({ wcomX, wcomY, wcomZ }, { x, y, z }, { rotX, rotY, rotZ }, terrainY) < 0.75 then
							if WoodHarvesterSound.checkIsInRange(self, v) then
								if getUserAttribute(v, "whs_hasFelled") ~= true then
									if not self.whs.isFallPlaying then
										WoodHarvesterSound.playSound(self, g_currentMission.whs.samplesFall, v, "Fall")
										setUserAttribute(v, "whs_hasFelled", "Boolean", true)
									end
								end
							end
						end

						-- Log vs Log Collision logic
						for j, vv in pairs(self.whs.logs) do
							local isAttached = (self.spec_woodHarvester.attachedSplitShape == v)
							local isOtherAttached = (spec ~= nil and self.spec_woodHarvester.attachedSplitShape == vv)

							if v ~= vv and not isAttached and not isOtherAttached and entityExists(vv) and self.spec_woodHarvester.attachedSplitShape ~= nil then
								local vx2, vy2, vz2 = getLinearVelocity(vv)
								local relVel = MathUtil.vector3Length(vx - vx2, vy - vy2, vz - vz2)

								if relVel > 0.4 then
									local x, y, z = getWorldTranslation(v)
									local rx, ry, rz = getWorldRotation(v)

									local sizeX, sizeY, sizeZ = getSplitShapeStats(v)

									self.whs.overlapTarget = vv
									self.whs.overlapHit = false

									overlapBox(x, y, z, rx, ry, rz, sizeX / 2, sizeY / 2, sizeZ / 2, "whs_overlapCallback", self, CollisionFlag.TREE, true, true, true)

									if self.whs.overlapHit then
											if WoodHarvesterSound.checkIsInRange(self, v) then
												if not self.whs.isLogsPlaying then
													WoodHarvesterSound.playSound(self, g_currentMission.whs.samplesLogs,
														v, "Logs")
											end
										end
									end
								end
							end
						end
					end
				else
					self.whs.logs[logId] = nil
				end
			end
		end
	end
end

function timeToGround(com, pivot, angularVel, terrainHeight)
	local rx = com[1] - pivot[1]
	local ry = com[2] - pivot[2]
	local rz = com[3] - pivot[3]

	local vy = (angularVel[3] * rx) - (angularVel[1] * rz)

	local dy = com[2] - terrainHeight

	if vy >= 0 then
		return 999
	end

	return dy / -vy
end

function WoodHarvesterSound:collisionTestCallback(otherId, ...)
	if otherId ~= 0 then
		if getRigidBodyType(otherId) == RigidBodyType.DYNAMIC then
			self.whs.currentScanFound[otherId] = true
			self.whs.logs[otherId] = otherId
		end
	end
end

function WoodHarvesterSound:playSound(samples, node, typeName)
	if samples ~= nil and #samples > 0 then
		local index = math.random(1, #samples)
		local sample = samples[index]

		if self.isClient and sample ~= nil and sample ~= 0 then
			local x, y, z = getWorldTranslation(node)

			-- Try the 3D specific position function for STATICSAMPLE
			if setSample3DPosition ~= nil then
				setSample3DPosition(sample, x, y, z) --hmm this is not actually playing in the word just in my head
			end

			playSample(sample, 1, 1.0, 0.0, 0, 0)
			--TODO: setSamplePitch to change pitch based on diam
			self.whs["is" .. typeName .. "Playing"] = true
		end
	end
end

function WoodHarvesterSound:updatePlayingState(samples, typeName)
	local anyPlaying = false
	for _, sample in pairs(samples) do
		if sample ~= nil and sample ~= 0 then
			if isSamplePlaying(sample) then
				anyPlaying = true
				break
			end
		end
	end
	self.whs["is" .. typeName .. "Playing"] = anyPlaying
end

function WoodHarvesterSound:checkIsInRange(node)
	local tx, ty, tz

	if g_localPlayer ~= nil and g_localPlayer.rootNode ~= 0 then
		tx, ty, tz = getWorldTranslation(g_localPlayer.rootNode)
	end
	if tx ~= nil and node ~= nil and entityExists(node) then
		local x2, y2, z2 = getWorldTranslation(node)
		local dist = MathUtil.vector3Length(tx - x2, ty - y2, tz - z2)
		return dist < 4000
	end

	return false
end

function WoodHarvesterSound:onDraw()
	if self.isClient and self:getIsActive() and self.whs.debug then
		setTextColor(0, 6307, 0, 6307, 0.6307, 1)
		renderText(0, 55, 0, 75, 0.013, "WHS Active Logs: " .. tostring(table.size(self.whs.logs)))
		for i, v in pairs(self.whs.logs) do
			if entityExists(v) then
				local x, y, z = getWorldTranslation(v)
				local vx, vy, vz = getLinearVelocity(v)
				local vel = MathUtil.vector3Length(vx, vy, vz)
				drawDebugLine(x, y, z, 1, 0, 0, x + vx, y + vy, z + vz, 1, 1, 1)
				renderTextAtWorldPos(x, y + 0.5, z, string.format("Vel: %.2f", vel))
			end
		end
	end
end

function whs_overlapCallback(shapeId, x, y, z, distance)
	if shapeId == g_currentMission.whs.overlapTarget then
		g_currentMission.whs.overlapHit = true
	end
	return true
end