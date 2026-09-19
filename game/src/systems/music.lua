local love = require("love")
local MusicSystem = {}
MusicSystem.__index = MusicSystem

---@class Track
---@field name string
---@field path string
---@field source love.Source

---@class MusicSystem
---@field private tracks Track[]
---@field private currentTrackIndex integer
---@return MusicSystem
function MusicSystem:new()
	self.tracks = {
		{ name = "HighHealth", path = "assets/audio/music/high-health-theme.mp3" },
		{ name = "LowHealth", path = "assets/audio/music/low-health-theme.mp3" },
		{ name = "Overhealed", path = "assets/audio/music/overhealed-theme.mp3" },
	}
	self.currentTrackIndex = 1
	self:startAllTracks()
	self:enableCurrentTrack()
	return setmetatable({ currentTrackIndex = self.currentTrackIndex }, MusicSystem)
end

function MusicSystem:startAllTracks()
	for _, track in ipairs(self.tracks) do
		track.source = love.audio.newSource(track.path, "stream")
		track.source:setLooping(true)
		track.source:play()
	end
end

function MusicSystem:setTrack(trackName)
	for index, track in ipairs(self.tracks) do
		if track.name == trackName then
			self.currentTrackIndex = index
			self:enableCurrentTrack()
			break
		end
	end
end

function MusicSystem:enableCurrentTrack()
	for i, track in ipairs(self.tracks) do
		if i == self.currentTrackIndex then
			track.source:setVolume(1.0)
		else
			if track.source:isPlaying() then
				track.source:setVolume(0.0)
			end
		end
	end
end

function MusicSystem:receiveHealthUpdate(healthPercentage)
	if healthPercentage > 1.0 then
		self:setTrack("Overhealed")
	elseif healthPercentage > 0.5 then
		self:setTrack("HighHealth")
	else
		self:setTrack("LowHealth")
	end
end

return MusicSystem
