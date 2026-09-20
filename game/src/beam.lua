local vector = require("lib.hump.vector")

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

	setmetatable(beam, Beam)

	return beam
end

function Beam:releaseBeam(dt)
	if not self.isVisible then
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

function Beam:draw()
	if not self.isVisible then
		return
	end

	if self.length <= 0 then
		return
	end

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

	local segments = 20
	local halfWidth = self.width / 2

	for i = 0, segments - 1 do
		local t0 = i / segments
		local t1 = (i + 1) / segments

		local point0 =
			self:bezier(p0, p1, p2, t0)

		local point1 =
			self:bezier(p0, p1, p2, t1)

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
	self.isActive = false
end

return Beam

