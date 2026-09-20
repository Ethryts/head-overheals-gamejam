local vector = require("lib.hump.vector")
local BeamVisual = require("src.beam_visual")
local Gamestate = require("gamestate.deps").Gamestate

local Beam = {}
Beam.__index = Beam

---@class Beam
---@field mode "heal"|"death" Beam effect applied to targets it overlaps.
---@field impact? {position: HumpVector, angle: number} First world contact, with direction back along the beam.
---@field impactCooldown? number Seconds until the next contact burst.
function Beam:new(bottomLeft, direction, mode)
	local beam = {
		bottomLeft = bottomLeft,
		direction = direction,
		mode = mode or "heal",

		length = 0,
		maxLength = 200,
		width = 10,

		tip = bottomLeft:clone(),

		targetTip = bottomLeft:clone(),

		tipSpeed = 600,

		previousDirection = direction:clone(),
		angularVelocity = 0,

		bend = 0,
		bendVelocity = 0,

		isActive = true,
		isVisible = true,
		visual = BeamVisual.new(),
	}

	Gamestate.soundEffectsSystem:playSoundEffect("HealingStart", true)

	setmetatable(beam, Beam)

	return beam
end

function Beam:releaseBeam(dt)
	if not self.isVisible then
		return
	end

	-- Retract along the already clipped path so released beams cannot emerge
	-- on the far side of an obstruction as their tail advances.
	if self.points then
		local remaining = 1000 * dt
		while #self.points > 1 do
			local segment = self.points[2] - self.points[1]
			local distance = segment:len()
			if distance > remaining then
				self.points[1] = self.points[1] + segment:normalized() * remaining
				break
			end
			remaining = remaining - distance
			table.remove(self.points, 1)
		end
		self.bottomLeft = self.points[1]:clone()
		self.tip = self.points[#self.points]:clone()
		self.length = (self.tip - self.bottomLeft):len()
		self.isVisible = #self.points > 1
		return
	end

	local toTip = self.tip - self.bottomLeft
	local distance = toTip:len()

	if distance <= 0 then
		self.bottomLeft = self.tip:clone()
		self.length = 0
		self.isVisible = false
		return
	end

	local releaseSpeed = 1000

	local movement = math.min(
		releaseSpeed * dt,
		distance
	)

	self.bottomLeft =
		self.bottomLeft + toTip:normalized() * movement

	self.length =
		(self.tip - self.bottomLeft):len()

	if self.length <= 1 then
		self.bottomLeft = self.tip:clone()
		self.length = 0
		self.isVisible = false
	end
end

function Beam:update(dt, newPosition, direction, mode)
	if not self.isVisible then return end
	if not self.isActive then
		self:releaseBeam(dt)
		self.visual:update(self, dt)
		return
	end
	self.points = nil
	Gamestate.soundEffectsSystem:playSoundEffect("HealingPassive", false)

	self.bottomLeft = newPosition
	if mode then self.mode = mode end

	if direction then
		self.direction = direction

		local cross =
			self.previousDirection.x * self.direction.y -
			self.previousDirection.y * self.direction.x

		local dot =
			self.previousDirection.x * self.direction.x +
			self.previousDirection.y * self.direction.y

		local angleDelta = math.atan2(cross, dot)

		if dt > 0 then
			self.angularVelocity = angleDelta / dt
		end

		self.previousDirection = self.direction:clone()
	end

	if self.direction then
		self.targetTip =
			self.bottomLeft + self.direction * self.maxLength
	end

	local toTarget = self.targetTip - self.tip
	local distance = toTarget:len()

	if distance > 0 then
		local movement = math.min(
			self.tipSpeed * dt,
			distance
		)

		self.tip = self.tip + toTarget:normalized() * movement
	end

	self.length = (self.tip - self.bottomLeft):len()


	local targetBend = self.angularVelocity * 20

	local maxBend = 100

	targetBend = math.max(
		-maxBend,
		math.min(maxBend, targetBend)
	)

	local bendAcceleration = 800

	self.bendVelocity =
		self.bendVelocity
		+ (targetBend - self.bend) * bendAcceleration * dt

	local damping = 0.85

	self.bendVelocity =
		self.bendVelocity * math.pow(damping, dt * 60)

	self.bend = self.bend + self.bendVelocity * dt
	self.visual:update(self, dt)
end

-- Rendering and healing use the same sampled curve, stopped at its first impact.
function Beam:getPoints()
	if self.points then return self.points end
	local p0 = self.bottomLeft
	local p2 = self.tip

	local midpoint = (p0 + p2) / 2

	local beamDirection = (p2 - p0):normalized()

	local perpendicular = vector(
		-beamDirection.y,
		beamDirection.x
	)

	local p1 =
		midpoint + perpendicular * self.bend

	local points = {p0}
	for i = 1, 20 do
		points[#points + 1] = self:bezier(p0, p1, p2, i / 20)
	end
	return points
end

function Beam:clipAgainstWorld(traceWorld, origin)
	self.impact = nil
	if origin and self.isActive then self.bottomLeft = origin end
	if self.isActive then self.points = nil end
	self.traceWorld = traceWorld
	local points = self:getPoints()
	local clipped = {points[1]}
	for i = 2, #points do
		local first, last = points[i - 1], points[i]
		local hit = traceWorld(first, last, self.width / 2)
		if hit then
			self.impact = {
				position = first + (last - first) * hit,
				angle = math.atan2(first.y - last.y, first.x - last.x),
			}
			if hit > 0 then clipped[#clipped + 1] = first + (last - first) * hit end
			break
		end
		clipped[#clipped + 1] = last
	end
	self.points = clipped
	self.visual:update(self, 0)
end

---@param dt number
---@param fx FxSystem
function Beam:updateImpact(dt, fx)
  if not self.isActive or not self.isVisible or not self.impact then
    self.impactCooldown = 0
    return
  end
  self.impactCooldown = (self.impactCooldown or 0) - dt
  if self.impactCooldown <= 0 then
    local contact = self.impact
    fx:emit("beam_impact", contact.position.x, contact.position.y, {angle = contact.angle})
    -- At most one burst per update, with no catch-up flood after a slow frame.
    self.impactCooldown = 0.08
  end
end

function Beam:draw()
  if self.isVisible and self.length > 0 then self.visual:draw() end
end

function Beam:destroy()
  self.visual:destroy()
  self.isVisible = false
end

function Beam:bezier(p0, p1, p2, t)
	local a = (1 - t) * (1 - t)
	local b = 2 * (1 - t) * t
	local c = t * t

	return p0 * a + p1 * b + p2 * c
end

function Beam:startRelease()
	Gamestate.soundEffectsSystem:playSoundEffect("HealingEnd", true)
	Gamestate.soundEffectsSystem:stopSoundEffect("HealingPassive", true)

	self.isActive = false
end

function Beam:containsPoint(point, fuzziness)

	if not self.isVisible then
		return false
	end

	fuzziness = fuzziness or 0

	local points = self:getPoints()

	-- Normal beam radius + fuzziness
	local collisionRadius =
		self.width / 2 + fuzziness

	local collisionRadiusSquared =
		collisionRadius * collisionRadius

	for i = 1, #points - 1 do
		local point0, point1 = points[i], points[i + 1]

		-- Vector along this beam segment
		local segment = point1 - point0

		local segmentLengthSquared =
			segment.x * segment.x +
			segment.y * segment.y

		-- Find closest point on the segment
		local t = 0

		if segmentLengthSquared > 0 then
			t =
				((point.x - point0.x) * segment.x +
				 (point.y - point0.y) * segment.y)
				/ segmentLengthSquared

			t = math.max(0, math.min(1, t))
		end

		local closestPoint =
			point0 + segment * t

		-- Distance from test point to beam
		local difference =
			point - closestPoint

		local distanceSquared =
			difference.x * difference.x +
			difference.y * difference.y

		if distanceSquared <= collisionRadiusSquared
			and (not self.traceWorld or not self.traceWorld(closestPoint, point, 0)) then
			return true
		end
	end

	return false
end


return Beam
