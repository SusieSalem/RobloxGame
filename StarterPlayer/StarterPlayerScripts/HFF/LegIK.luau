-- LegIK
-- Each foot stays planted on the ground until the body moves too far from it,
-- then steps to a new spot under the torso (led by velocity). A two-bone IK
-- solve turns each foot target into hip and knee angles for the drives.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Drives = require(script.Parent.Drives)

local Config = Shared.Config
local poseDrive = Drives.pose

local LegIK = {}

local function soleOf(foot: BasePart): Vector3
	return foot.Position - Vector3.new(0, foot.Size.Y / 2, 0)
end

local function solveLeg(leg, target: Vector3, torque: number)
	local lowerTorso = leg.hipJoint.part0
	local hip = leg.hipJoint.a0.WorldPosition
	local localTarget = lowerTorso.CFrame:VectorToObjectSpace(target - hip)
	local thigh, shin = leg.thigh, leg.shin
	local reach = math.clamp(localTarget.Magnitude, math.abs(thigh - shin) + 0.05, thigh + shin - 0.02)
	local direction = if localTarget.Magnitude > 1e-3 then localTarget.Unit else Vector3.new(0, -1, 0)

	-- Law of cosines: how far the thigh tilts forward of the hip->foot line,
	-- and the knee's inner angle.
	local thighOffset = math.acos(math.clamp((thigh * thigh + reach * reach - shin * shin) / (2 * thigh * reach), -1, 1))
	local kneeInner = math.acos(math.clamp((thigh * thigh + shin * shin - reach * reach) / (2 * thigh * shin), -1, 1))

	local forward = math.atan2(-direction.Z, -direction.Y) + thighOffset
	local side = math.asin(math.clamp(direction.X, -1, 1))
	poseDrive(leg.hipDrive, forward, side, torque)
	poseDrive(leg.kneeDrive, -(math.pi - kneeInner), 0, torque)
end

-- Returns how many feet landed this frame.
function LegIK.update(rigState, dt: number, flatVelocity: Vector3, strength: number): number
	local legs = rigState.ikLegs
	local facing = CFrame.Angles(0, rigState.facingYaw, 0)
	local right = facing.RightVector
	local forward = facing.LookVector

	if not rigState.ikActive then
		-- (Re)starting IK, e.g. after getting up: plant feet where they are.
		for _, leg in legs do
			leg.planted = soleOf(leg.foot)
			leg.stepping = false
		end
		rigState.ikActive = true
	end

	-- Feet want to be under the upper torso (which moves with any tilt), a
	-- little ahead in the direction of travel.
	local center = rigState.core.Position + flatVelocity * Config.StepLead
	local anyStepping = false
	local worst, worstDistance = nil, Config.StepDistance
	for _, leg in legs do
		anyStepping = anyStepping or leg.stepping
		local spot = center + right * (leg.sideSign * leg.spacing)
		local hit = Workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -(rigState.standHeight + 6), 0), rigState.raycastParams)
		leg.spot = if hit then hit.Position else nil
		if leg.spot and not leg.stepping then
			local offset = leg.spot - leg.planted
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance > worstDistance then
				worst, worstDistance = leg, distance
			end
		end
	end

	-- One foot at a time, the one furthest behind.
	if worst and not anyStepping then
		local speedAlpha = math.clamp(flatVelocity.Magnitude / Config.WalkSpeed, 0, 1)
		worst.stepping = true
		worst.from = worst.planted
		worst.to = worst.spot
		worst.t = 0
		worst.duration = Config.StepDuration * (1 - 0.4 * speedAlpha)
	end

	local landed = 0
	local torque = Config.LegMaxTorque * strength
	local targets = {}
	for side, leg in legs do
		local target = leg.planted
		if leg.stepping then
			if leg.spot then
				leg.to = leg.to:Lerp(leg.spot, 0.25) -- follow the body a bit mid-step
			end
			leg.t = math.min(leg.t + dt / leg.duration, 1)
			target = leg.from:Lerp(leg.to, leg.t) + Vector3.new(0, math.sin(leg.t * math.pi) * Config.StepHeight, 0)
			if leg.t >= 1 then
				leg.stepping = false
				leg.planted = leg.to
				target = leg.planted
				landed += 1
			end
		end
		targets[side] = target
		solveLeg(leg, target, torque)
	end

	-- Arm swing follows the feet: left foot ahead -> positive.
	if targets.Left and targets.Right then
		local stride = forward:Dot(targets.Left - targets.Right)
		rigState.ikSwing = math.clamp(stride / 2, -1, 1) * math.rad(Config.StrideAngle)
	end
	return landed
end

return LegIK
