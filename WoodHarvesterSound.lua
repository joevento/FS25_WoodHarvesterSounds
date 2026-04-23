local modDir = g_currentModDirectory or ""
local NUM_SOUND_NODES = 8

WoodHarvesterSound = {}
WoodHarvesterSound.modDir = modDir

local whs = {}

function WoodHarvesterSound:loadMap(filename)
	whs.logs = {}
	whs.lastAngVel = {}
	whs.currentScanFound = {}
	whs.playingSound = {}
	whs.timer = 0
	whs.searchRadius = 75
	whs.isLogsPlaying = false
	whs.bvhDirty = true
	whs.cachedEntries = {}
	whs.cachedBVH = nil
	whs.entryCache = {}

	local xmlPath = Utils.getFilename("Sounds/woodHarvesterSounds.xml", modDir)
	local xmlFile = loadXMLFile("WoodHarvesterSoundXML", xmlPath)

	if xmlFile ~= nil and xmlFile ~= 0 then
		local components = { { node = getRootNode() } }

		whs.samplesLogs = g_soundManager:loadSamplesFromXML(
			xmlFile, "woodHarvesterSound.sounds", "logs",
			modDir, components, 1, AudioGroup.ENVIRONMENT, nil, nil
		)
		whs.samplesGround = g_soundManager:loadSamplesFromXML(
			xmlFile, "woodHarvesterSound.sounds", "ground",
			modDir, components, 1, AudioGroup.ENVIRONMENT, nil, nil
		)
		whs.samplesFall = g_soundManager:loadSamplesFromXML(
			xmlFile, "woodHarvesterSound.sounds", "fall",
			modDir, components, 1, AudioGroup.ENVIRONMENT, nil, nil
		)

		delete(xmlFile)
	end

	whs.soundNodePool = {}
	for i = 1, NUM_SOUND_NODES do
		local node = createTransformGroup("whs_soundNode_" .. i)
		link(getRootNode(), node)
		table.insert(whs.soundNodePool, { node = node, inUse = false, sample = nil })
	end
end

function WoodHarvesterSound:deleteMap()
	if whs.samplesLogs ~= nil then
		g_soundManager:deleteSamples(whs.samplesLogs)
	end
	if whs.samplesGround ~= nil then
		g_soundManager:deleteSamples(whs.samplesGround)
	end
	if whs.samplesFall ~= nil then
		g_soundManager:deleteSamples(whs.samplesFall)
	end

	if whs.soundNodePool ~= nil then
		for _, entry in ipairs(whs.soundNodePool) do
			if entry.node ~= nil and entry.node ~= 0 then
				delete(entry.node)
			end
		end
	end
	whs = {}
end

local function acquireSoundNode()
	for _, entry in ipairs(whs.soundNodePool) do
		if not entry.inUse then
			entry.inUse = true
			return entry
		end
	end
	return nil
end

local function releaseSoundNodes()
	for _, entry in ipairs(whs.soundNodePool) do
		if entry.inUse and entry.sample ~= nil then
			if not g_soundManager:getIsSamplePlaying(entry.sample) then
				entry.inUse = false
				entry.sample = nil
			end
		end
	end
end

local function playSound(samples, x, y, z, override)
	local factor = g_soundMixer.volumeFactors[3] --environment
	if samples == nil or #samples == 0 then return end

	local entry = acquireSoundNode()
	if entry == nil then return end

	local index = 0
	if override == nil then
		index = math.random(1, #samples)
	else
		index = math.min(override, #samples)
	end
	local sample = samples[index]

	if sample == nil then
		entry.inUse = false
		return
	end

	setWorldTranslation(sample.soundNode, x, y, z)
	local pitch = g_soundManager:getCurrentSamplePitch(sample)
	pitch = pitch + (math.random() * 0.4 - 0.2)
	--Doesn't seem to actually change it tho, giants problem?
	g_soundManager:setSamplePitch(sample, pitch)
	g_soundManager:setSampleVolume(sample, factor)
	g_soundManager:playSample(sample)
	entry.sample = sample
	return sample
end

local function getPlayerPos()
    if g_localPlayer ~= nil then
        local vehicle = g_localPlayer:getCurrentVehicle()
        if vehicle ~= nil and vehicle.rootNode ~= nil and vehicle.rootNode ~= 0 then
            return getWorldTranslation(vehicle.rootNode)
        end
        if g_localPlayer.rootNode ~= nil and g_localPlayer.rootNode ~= 0 then
            local x, y, z = getWorldTranslation(g_localPlayer.rootNode)
            if y > -100 then
                return x, y, z
            end
        end
    end
    return nil, nil, nil
end

local function checkIsInRange(node)
	local tx, ty, tz = getPlayerPos()
	if tx ~= nil and node ~= nil and entityExists(node) then
		local x2, y2, z2 = getWorldTranslation(node)
		local dist = MathUtil.vector3Length(tx - x2, ty - y2, tz - z2)
		return dist < whs.searchRadius
	end

	return false
end

local function buildLogEntries(logs)
	local entries = {}
	for logId, v in pairs(logs) do
		if v ~= nil and entityExists(v) then
			local lvx, lvy, lvz = getLinearVelocity(v)
			local speedSq = lvx * lvx + lvy * lvy + lvz * lvz
			local cached = whs.entryCache[logId]

			if cached ~= nil and speedSq < 0.01 then
				cached.lvx, cached.lvy, cached.lvz = lvx, lvy, lvz
				entries[#entries + 1] = cached
			else
				local sizeX, sizeY, _, _, _ = getSplitShapeStats(v)
				local cylRadius             = sizeY * 0.5
				local halfLen               = sizeX * 0.5
				local comX, comY, comZ      = getCenterOfMass(v)
				local wcx, wcy, wcz         = localToWorld(v, comX, comY, comZ)
				local dx, dy, dz            = localDirectionToWorld(v, 0, 1, 0)
				local ox, oy, oz            = wcx - dx * halfLen, wcy - dy * halfLen, wcz - dz * halfLen
				local ex, ey, ez            = wcx + dx * halfLen, wcy + dy * halfLen, wcz + dz * halfLen
				local bsr                   = math.sqrt(halfLen * halfLen + cylRadius * cylRadius)
				local entry = {
					id      = logId,
					v       = v,
					cx      = wcx,   cy  = wcy,    cz  = wcz,
					r       = bsr,
					halfLen = halfLen,
					radius  = cylRadius,
					sx      = ox,    sy  = oy,     sz  = oz,
					ex      = ex,    ey  = ey,     ez  = ez,
					lvx     = lvx,   lvy = lvy,    lvz = lvz,
				}
				whs.entryCache[logId] = entry
				entries[#entries + 1] = entry
			end
		end
	end
	return entries
end

local function buildBVHNode(entries)
	if #entries == 0 then return nil end

	if #entries <= 6 then
		local cx, cy, cz = 0, 0, 0
		for _, e in ipairs(entries) do
			cx = cx + e.cx
			cy = cy + e.cy
			cz = cz + e.cz
		end
		cx = cx / #entries
		cy = cy / #entries
		cz = cz / #entries
		local r = 0
		for _, e in ipairs(entries) do
			local dx = e.cx - cx
			local dy = e.cy - cy
			local dz = e.cz - cz
			local d  = math.sqrt(dx * dx + dy * dy + dz * dz) + e.r
			if d > r then r = d end
		end
		return { leaf = true, entries = entries, cx = cx, cy = cy, cz = cz, r = r }
	end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, e in ipairs(entries) do
		if e.cx < minX then minX = e.cx end
		if e.cx > maxX then maxX = e.cx end
		if e.cy < minY then minY = e.cy end
		if e.cy > maxY then maxY = e.cy end
		if e.cz < minZ then minZ = e.cz end
		if e.cz > maxZ then maxZ = e.cz end
	end

	local dx = maxX - minX
	local dy = maxY - minY
	local dz = maxZ - minZ
	local axis
	if dx >= dy and dx >= dz then
		axis = "cx"
	elseif dy >= dz then
		axis = "cy"
	else
		axis = "cz"
	end

	table.sort(entries, function(a, b) return a[axis] < b[axis] end)

	local mid   = math.floor(#entries / 2)
	local left  = {}
	local right = {}
	for i = 1, mid do left[#left + 1] = entries[i] end
	for i = mid + 1, #entries do right[#right + 1] = entries[i] end

	local ncx = (minX + maxX) * 0.5
	local ncy = (minY + maxY) * 0.5
	local ncz = (minZ + maxZ) * 0.5
	local nr  = 0
	for _, e in ipairs(entries) do
		local ddx = e.cx - ncx
		local ddy = e.cy - ncy
		local ddz = e.cz - ncz
		local d   = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz) + e.r
		if d > nr then nr = d end
	end

	return {
		leaf = false,
		cx = ncx,
		cy = ncy,
		cz = ncz,
		r = nr,
		left  = buildBVHNode(left),
		right = buildBVHNode(right),
	}
end

local function queryBVHPairs(nodeA, nodeB, pairs)
	if nodeA == nil or nodeB == nil then return end

	local ddx    = nodeA.cx - nodeB.cx
	local ddy    = nodeA.cy - nodeB.cy
	local ddz    = nodeA.cz - nodeB.cz
	local distSq = ddx * ddx + ddy * ddy + ddz * ddz
	local rSum   = nodeA.r + nodeB.r
	if distSq > rSum * rSum then return end

	if nodeA.leaf and nodeB.leaf then
		for _, ea in ipairs(nodeA.entries) do
			for _, eb in ipairs(nodeB.entries) do
				if ea.id < eb.id then
					pairs[#pairs + 1] = { ea, eb }
				end
			end
		end
		return
	end

	if nodeA.leaf then
		queryBVHPairs(nodeA, nodeB.left, pairs)
		queryBVHPairs(nodeA, nodeB.right, pairs)
	elseif nodeB.leaf then
		queryBVHPairs(nodeA.left, nodeB, pairs)
		queryBVHPairs(nodeA.right, nodeB, pairs)
	else
		queryBVHPairs(nodeA.left, nodeB.left, pairs)
		queryBVHPairs(nodeA.left, nodeB.right, pairs)
		queryBVHPairs(nodeA.right, nodeB.left, pairs)
		queryBVHPairs(nodeA.right, nodeB.right, pairs)
	end
end

local function querySelfPairs(node, pairs)
	if node == nil or node.leaf then
		if node ~= nil then
			local entries = node.entries
			for i = 1, #entries do
				for j = i + 1, #entries do
					pairs[#pairs + 1] = { entries[i], entries[j] }
				end
			end
		end
		return
	end
	queryBVHPairs(node.left, node.right, pairs)
	querySelfPairs(node.left, pairs)
	querySelfPairs(node.right, pairs)
end

local function isHorizontal(id)
	local rx, _, rz = getWorldRotation(id)
	return (math.abs(math.cos(rx) * math.cos(rz)) < 0.75)
end

function WoodHarvesterSound:update(dt)
	if whs.soundNodePool == nil then
		return
	end

	releaseSoundNodes()

	whs.timer = whs.timer + dt
	if whs.timer < 75 then
		return
	end
	whs.timer = 0

	local px, py, pz = getPlayerPos()
	if px == nil then
		return
	end

	whs.currentScanFound = {}

	local mask = 2048 + 262144 + 16777216
	overlapSphere(px, py, pz, whs.searchRadius, "collisionTestCallback", self, mask, true, false, true, false)

	if next(whs.currentScanFound) ~= nil then
		for logId in pairs(whs.logs) do
			if not whs.currentScanFound[logId] then
				whs.logs[logId] = nil
				whs.entryCache[logId] = nil
				whs.bvhDirty = true
			end
		end
	end
	local vehicle = g_localPlayer:getCurrentVehicle()

	for logId, v in pairs(whs.logs) do
		repeat
			if v ~= nil and entityExists(v) then
				if whs.playingSound[v] ~= nil then
					if g_soundManager:getIsSamplePlaying(whs.playingSound[v]) then
						break
					end
					whs.playingSound[v] = nil
				end
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

					whs.lastAngVel[v] = angVelocity

					-- Ground Impact
					if (comDistToGround < 0.5 and -vy > 0.5) then
						if checkIsInRange(v) then
							whs.playingSound[v] = playSound(whs.samplesGround, wcomX, wcomY, wcomZ)
						end
					end

					-- Tree Falling
					if vehicle ~= nil and vehicle.spec_woodHarvester then
						if not isHorizontal(v) and vehicle.spec_woodHarvester.hasAttachedSplitShape then
							local selectedIndex = nil
							local sizeX, _, _   = getSplitShapeStats(v)
							if sizeX < 12 then
								selectedIndex = 1
							end
							if selectedIndex == nil then
								selectedIndex = math.random(1, #whs.samplesFall)
							end

							local threshold = (selectedIndex == 1) and 1 or 25
							local ttg = timeToGround({ wcomX, wcomY, wcomZ }, { x, y, z }, { rotX, rotY, rotZ }, terrainY)

							if ttg < threshold then
								if checkIsInRange(v) then
									whs.playingSound[v] = playSound(whs.samplesFall, wcomX, wcomY, wcomZ, selectedIndex)
								end
							end
						end
					end
				end
			else
				whs.logs[logId] = nil
				whs.entryCache[logId] = nil
				whs.bvhDirty = true
			end
		until true
	end

	-- Log vs Log Collision logic
	if whs.bvhDirty then
		whs.cachedEntries = buildLogEntries(whs.logs)
		whs.cachedBVH = #whs.cachedEntries > 1 and buildBVHNode(whs.cachedEntries) or nil
		whs.bvhDirty = false
	end

	if whs.cachedBVH ~= nil then
		local logPairs = {}
		querySelfPairs(whs.cachedBVH, logPairs)

		for _, pair in ipairs(logPairs) do
			local skip = false
			local ea = pair[1]
			local eb = pair[2]

			if vehicle ~= nil and vehicle.spec_logGrab then
				local spec = vehicle.spec_logGrab
				for _, grab in ipairs(spec.grabs) do
					for shapeId, _ in pairs(grab.dynamicMountedShapes) do
						if shapeId == ea.v or shapeId == eb.v then
							skip = true
						end
					end
				end
			end

			if getUserAttribute(ea.id, "isTensionBeltMounted") and getUserAttribute(eb.id, "isTensionBeltMounted") == true then
				skip = true
			end

			local v = ea.v
			if not skip then
				if (whs.playingSound[v] == nil or not g_soundManager:getIsSamplePlaying(whs.playingSound[v])) and math.random() < 0.5 then
					local relVel = MathUtil.vector3Length(
						ea.lvx - eb.lvx,
						ea.lvy - eb.lvy,
						ea.lvz - eb.lvz
						)

						if relVel > 0.5 then
							local combinedRadius = ea.radius + eb.radius

							local dist = closestDistBetweenSegments(
								{ ea.sx, ea.sy, ea.sz }, { ea.ex, ea.ey, ea.ez },
								{ eb.sx, eb.sy, eb.sz }, { eb.ex, eb.ey, eb.ez }
								)

								if dist < combinedRadius then
									if checkIsInRange(v) and not whs.isLogsPlaying then
										whs.playingSound[v] = playSound(whs.samplesLogs, ea.cx, ea.cy, ea.cz)
									end
								end
							end
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

function WoodHarvesterSound:collisionTestCallback(otherId)
	if otherId ~= 0 then
		if getRigidBodyType(otherId) == RigidBodyType.DYNAMIC and getSplitType(otherId) ~= 0 then
			whs.currentScanFound[otherId] = true
			if whs.logs[otherId] == nil then
				whs.bvhDirty = true
			end
			whs.logs[otherId] = otherId
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

addModEventListener(WoodHarvesterSound)
