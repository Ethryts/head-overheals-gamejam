---@class Effect
---@field name string
---@field path string
---@field source any

---@class SoundEffectsSystem
---@field private effects Effect[]
local SoundEffectsSystem = {}
SoundEffectsSystem.__index = SoundEffectsSystem
---@return SoundEffectsSystem
function SoundEffectsSystem:new()
	self.effects = {
		{ name = "Death", path = "assets/audio/sfx/death.wav", source = nil },
		{ name = "Pickup", path = "assets/audio/sfx/pickup.mp3", source = nil },
		{ name = "Powerup", path = "assets/audio/sfx/powerup.mp3", source = nil },
		{ name = "Step", path = "assets/audio/sfx/step.wav", source = nil },
		{ name = "HealingStart", path = "assets/audio/sfx/healing-start.wav", source = nil },
		{ name = "HealingEnd", path = "assets/audio/sfx/healing-end.wav", source = nil },
		{ name = "HealingPassive", path = "assets/audio/sfx/healing-passive.wav", source = nil },
		{ name = "HeadOverhealed", path = "assets/audio/sfx/head-overhealed.mp3", source = nil },
		{ name = "HealingPassive", path = "assets/audio/sfx/healing-passive.wav", source = nil },
		{ name = "SlimeDeath", path = "assets/audio/sfx/slimed-out.mp3", source = nil },
		{ name = "EyeballDeath", path = "assets/audio/sfx/eyeball-death.mp3", source = nil },
		{ name = "GeneralDeath", path = "assets/audio/sfx/general-death.mp3", source = nil },
		{ name = "Swing", path = "assets/audio/sfx/swing.mp3", source = nil },
		{ name = "Kick", path = "assets/audio/sfx/kick.mp3", source = nil },
	}

	self:loadAllEffects()
	return setmetatable({ effects = self.effects }, SoundEffectsSystem)
end

function SoundEffectsSystem:loadAllEffects()
	for _, effect in ipairs(self.effects) do
		effect.source = love.audio.newSource(effect.path, "static")
	end
end

function SoundEffectsSystem:playSoundEffect(effectName, force)
	for _, effect in ipairs(self.effects) do
		if effect.name == effectName then
			if effect.source:isPlaying() then
				if force then
					local clone = effect.source:clone()
					clone:play()
				else
					return
				end
			end
			effect.source:play()
			break
		end
	end
end

function SoundEffectsSystem:stopSoundEffect(effectName)
	for _, effect in ipairs(self.effects) do
		if effect.name == effectName then
			effect.source:stop()
			break
		end
	end
end

function SoundEffectsSystem:stopAllSoundEffects()
	for _, effect in ipairs(self.effects) do
		effect.source:stop()
	end
end

function SoundEffectsSystem:playWithLowPass(effectName)
	for _, effect in ipairs(self.effects) do
		if effect.name == effectName then
			effect.source:setFilter{type = "lowpass", highgain = math.random(1,10)/10}
			effect.source:play()
			break
		end
	end
end

return SoundEffectsSystem
