local vector = require("lib.hump.vector")
local Gamestate = require("gamestate.deps").Gamestate

local Beam = {}
Beam.__index = Beam

---@class Beam
function Beam:new(bottomLeft, direction)
	local beam = {
		bottomLeft = bottomLeft,
		direction = direction,

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

function Beam:update(dt, newPosition, direction)
	if not self.isActive then
		self:releaseBeam(dt)
		return
	end
	self.points = nil
	Gamestate.soundEffectsSystem:playSoundEffect("HealingPassive", false)

	self.bottomLeft = newPosition

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
	if origin and self.isActive then self.bottomLeft = origin end
	if self.isActive then self.points = nil end
	self.traceWorld = traceWorld
	local points = self:getPoints()
	local clipped = {points[1]}
	for i = 2, #points do
		local first, last = points[i - 1], points[i]
		local hit = traceWorld(first, last, self.width / 2)
		if hit then
			if hit > 0 then clipped[#clipped + 1] = first + (last - first) * hit end
			break
		end
		clipped[#clipped + 1] = last
	end
	self.points = clipped
end

function Beam:draw()
	if not self.isVisible then
		return
	end

	if self.length <= 0 then
		return
	end

	local points = self:getPoints()
	local halfWidth = self.width / 2
	for i = 1, #points - 1 do
		local point0, point1 = points[i], points[i + 1]

		local segmentDirection =
			(point1 - point0):normalized()

		local segmentPerpendicular = vector(
			-segmentDirection.y,
			segmentDirection.x
		)

		local left0 =
			point0 + segmentPerpendicular * halfWidth

		local right0 =
			point0 - segmentPerpendicular * halfWidth

		local left1 =
			point1 + segmentPerpendicular * halfWidth

		local right1 =
			point1 - segmentPerpendicular * halfWidth

		love.graphics.setColor(0.2, 1, 0.2, 0.7)

		love.graphics.polygon(
			"fill",

			left0.x, left0.y,
			right0.x, right0.y,
			right1.x, right1.y,
			left1.x, left1.y
		)
	end
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
