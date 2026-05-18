WoodHarvesterSoundEvent = {}
WoodHarvesterSoundEvent.__index = WoodHarvesterSoundEvent
local WoodHarvesterSoundEvent_mt = Class(WoodHarvesterSoundEvent, Event)

InitEventClass(WoodHarvesterSoundEvent, "WoodHarvesterSoundEvent")

local SOUND_TYPE_LOGS = 1
local SOUND_TYPE_GROUND = 2
local SOUND_TYPE_FALL = 3

function WoodHarvesterSoundEvent.emptyNew()
	return Event.new(WoodHarvesterSoundEvent_mt)
end

function WoodHarvesterSoundEvent.new(soundType, x, y, z, sampleIndex)
	local self = WoodHarvesterSoundEvent.emptyNew()
	self.soundType = soundType
	self.x = x
	self.y = y
	self.z = z
	self.sampleIndex = sampleIndex
	return self
end

function WoodHarvesterSoundEvent:writeStream(streamId, connection)
	streamWriteUInt8(streamId, self.soundType)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)
	streamWriteUInt8(streamId, self.sampleIndex)
end

function WoodHarvesterSoundEvent:readStream(streamId, connection)
	self.soundType = streamReadUInt8(streamId)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self.sampleIndex = streamReadUInt8(streamId)
end

function WoodHarvesterSoundEvent:run(connection)
	if not g_server then
		local samples
		if self.soundType == SOUND_TYPE_LOGS then
			samples = whs.samplesLogs
		elseif self.soundType == SOUND_TYPE_GROUND then
			samples = whs.samplesGround
		elseif self.soundType == SOUND_TYPE_FALL then
			samples = whs.samplesFall
		end
		playSound(samples, self.x, self.y, self.z, self.sampleIndex ~= 0 and self.sampleIndex or nil)
	end
end
