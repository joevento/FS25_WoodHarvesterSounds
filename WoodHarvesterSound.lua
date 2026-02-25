local NUM_SOUND_NODES = 8

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

	self.whs.root = self.rootNode
	self.whs.logs = {}
	self.whs.logsInfo = ""
	self.whs.logsInfo2 = ""
	self.whs.logsInfo3 = ""
	self.whs.timer = 0
	self.whs.debug = false
	self.whs.searchRadius = 1000

	if self.isClient then
		local modDir = WoodHarvesterSound.modDirectory
		local xmlPath = Utils.getFilename("sounds/woodHarvesterSounds.xml", modDir)
		local xmlFile = loadXMLFile("WoodHarvesterSoundXML", xmlPath)

		if xmlFile ~= nil and xmlFile ~= 0 then
			local components = { { node = getRootNode() } }

			self.whs.samplesLogs = g_soundManager:loadSamplesFromXML(
				xmlFile, "woodHarvesterSound.sounds", "logs",
				modDir, components, 1, AudioGroup.ENVIRONMENT, nil, nil
			)
			self.whs.samplesGround = g_soundManager:loadSamplesFromXML(
				xmlFile, "woodHarvesterSound.sounds", "ground",
				modDir, components, 1, AudioGroup.ENVIRONMENT, nil, nil
			)
			self.whs.samplesFall = g_soundManager:loadSamplesFromXML(
				xmlFile, "woodHarvesterSound.sounds", "fall",
				modDir, components, 1, AudioGroup.ENVIRONMENT, nil, nil
			)

			delete(xmlFile)
		end

		self.whs.soundNodePool = {}
		for i = 1, NUM_SOUND_NODES do
			local node = createTransformGroup("whs_soundNode_" .. i)
			link(getRootNode(), node)
			table.insert(self.whs.soundNodePool, { node = node, inUse = false, sample = nil })
		end
	end
end

function WoodHarvesterSound:onDelete()
	if self.isClient and self.whs ~= nil then
		if self.whs.samplesLogs ~= nil then
			g_soundManager:deleteSamples(self.whs.samplesLogs)
		end
		if self.whs.samplesGround ~= nil then
			g_soundManager:deleteSamples(self.whs.samplesGround)
		end
		if self.whs.samplesFall ~= nil then
			g_soundManager:deleteSamples(self.whs.samplesFall)
		end

		if self.whs.soundNodePool ~= nil then
			for _, entry in ipairs(self.whs.soundNodePool) do
				if entry.node ~= nil and entry.node ~= 0 then
					delete(entry.node)
				end
			end
		end
	end
end

function WoodHarvesterSound:acquireSoundNode()
	for _, entry in ipairs(self.whs.soundNodePool) do
		if not entry.inUse then
			entry.inUse = true
			return entry
		end
	end
	return nil
end

function WoodHarvesterSound:releaseSoundNodes()
	for _, entry in ipairs(self.whs.soundNodePool) do
		if entry.inUse and entry.sample ~= nil then
			if not g_soundManager:getIsSamplePlaying(entry.sample) then
				entry.inUse = false
				entry.sample = nil
			end
		end
	end
end

function WoodHarvesterSound:onUpdate(dt)
	if self:getIsActive() then
		if self.whs.lastAngVel == nil then
			self.whs.lastAngVel = {}
		end

		if self.isClient then
			WoodHarvesterSound.releaseSoundNodes(self)
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

						self.whs.lastAngVel[v] = angVelocity

						-- Ground Impact
						if not isAttached and ((comDistToGround < 0.25 and velocity > 0.125) or (comDistToGround < 0.5 and angVelocity > 0.5)) then
							if WoodHarvesterSound.checkIsInRange(self, v) then
								WoodHarvesterSound.playSound(self, self.whs.samplesGround, wcomX, wcomY, wcomZ)
							end
						end

						-- Tree Falling
						if timeToGround({ wcomX, wcomY, wcomZ }, { x, y, z }, { rotX, rotY, rotZ }, terrainY) < 0.75 then
							if WoodHarvesterSound.checkIsInRange(self, v) then
								if getUserAttribute(v, "whs_hasFelled") ~= true then
									WoodHarvesterSound.playSound(self, self.whs.samplesFall, wcomX, wcomY, wcomZ)
									setUserAttribute(v, "whs_hasFelled", "Boolean", true)
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
									local sizeX, sizeY, _   = getSplitShapeStats(v)
									local sizeX2, sizeY2, _ = getSplitShapeStats(vv)

									local halfLen1          = sizeX / 2
									local halfLen2          = sizeX2 / 2
									local combinedRadius    = (sizeY + sizeY2) / 2

									local v_start           = { localToWorld(v, 0, -halfLen1, 0) }
									local v_end             = { localToWorld(v, 0, halfLen1, 0) }
									local vv_start          = { localToWorld(vv, 0, -halfLen2, 0) }
									local vv_end            = { localToWorld(vv, 0, halfLen2, 0) }

									local dist              = closestDistBetweenSegments(v_start, v_end, vv_start, vv_end)

									if dist < combinedRadius then
										if WoodHarvesterSound.checkIsInRange(self, v) then
											if not self.whs.isLogsPlaying then
												WoodHarvesterSound.playSound(self, self.whs.samplesLogs, x, y, z)
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
		if getRigidBodyType(otherId) == RigidBodyType.DYNAMIC and getSplitType(otherId) ~= 0 then
			self.whs.currentScanFound[otherId] = true
			self.whs.logs[otherId] = otherId
		end
	end
end

function WoodHarvesterSound:playSound(samples, x, y, z)
	if not self.isClient then return end
	if samples == nil or #samples == 0 then return end

	local entry = WoodHarvesterSound.acquireSoundNode(self)
	if entry == nil then return end

	local index = math.random(1, #samples)
	local sample = samples[index]

	if sample == nil then
		entry.inUse = false
		return
	end

	setWorldTranslation(sample.soundNode, x, y, z)

	g_soundManager:playSample(sample)
	entry.sample = sample
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

function closestDistBetweenSegments(p1, p2, p3, p4)
	local d1 = { p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3] }
	local d2 = { p4[1] - p3[1], p4[2] - p3[2], p4[3] - p3[3] }
	local r  = { p1[1] - p3[1], p1[2] - p3[2], p1[3] - p3[3] }

	local a  = MathUtil.dotProduct(d1[1], d1[2], d1[3], d1[1], d1[2], d1[3])
	local e  = MathUtil.dotProduct(d2[1], d2[2], d2[3], d2[1], d2[2], d2[3])
	local f  = MathUtil.dotProduct(d2[1], d2[2], d2[3], r[1], r[2], r[3])

	local s, t
	if a <= 1e-10 and e <= 1e-10 then
		s, t = 0, 0
	elseif a <= 1e-10 then
		s, t = 0, math.max(0, math.min(f / e, 1))
	else
		local c = MathUtil.dotProduct(d1[1], d1[2], d1[3], r[1], r[2], r[3])
		if e <= 1e-10 then
			t = 0
			s = math.max(0, math.min(-c / a, 1))
		else
			local b = MathUtil.dotProduct(d1[1], d1[2], d1[3], d2[1], d2[2], d2[3])
			local denom = a * e - b * b
			if denom ~= 0 then
				s = math.max(0, math.min((b * f - c * e) / denom, 1))
			else
				s = 0
			end
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.max(0, math.min(-c / a, 1))
			elseif t > 1 then
				t = 1
				s = math.max(0, math.min((b - c) / a, 1))
			end
		end
	end

	local c1 = { p1[1] + d1[1] * s, p1[2] + d1[2] * s, p1[3] + d1[3] * s }
	local c2 = { p3[1] + d2[1] * t, p3[2] + d2[2] * t, p3[3] + d2[3] * t }
	return MathUtil.vector3Length(c1[1] - c2[1], c1[2] - c2[2], c1[3] - c2[3])
end
