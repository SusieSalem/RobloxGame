-- Balance
-- Gives standing a sense of weight. Instead of the torso being held bolt
-- upright like a gyroscope, its target tilt is a springy "sway" that the
-- body's own motion drives: it leans into speeding up, rocks back when
-- stopping and wobbles before settling, shifts its weight over the planted
-- foot while the other one steps, drops a little at each stride and squashes
-- on landing. In the air the balance muscles mostly let go.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Knockdown = require(script.Parent.Knockdown)

local Config = Shared.Config

local Balance = {}

-- Damped spring step. Works on numbers and Vector3s alike.
local function spring(position, velocity, target, frequency: number, dampingRatio: number, dt: number)
	local omega = 2 * math.pi * frequency
	local acceleration = (target - position) * (omega * omega) - velocity * (2 * dampingRatio * omega)
	velocity += acceleration * dt
	position += velocity * dt
	return position, velocity
end

function Balance.reset(rigState)
	rigState.sway = Vector3.zero -- radians; points the way the torso top leans
	rigState.swayVelocity = Vector3.zero
	rigState.heightOffset = 0 -- studs added to the stand height (negative = crouched)
	rigState.heightVelocity = 0
	rigState.smoothedAcceleration = Vector3.zero
	rigState.balanceLastVelocity = nil
	rigState.wasGrounded = true
	rigState.airTime = 0
	rigState.fallSpeed = 0
	rigState.balanceGrip = 1
end

-- Returns the tilt to put on top of the facing, a multiplier for the balance
-- torque, and how far to move the stand height.
function Balance.update(
	rigState,
	dt: number,
	grounded: boolean,
	moveDirection: Vector3,
	flatVelocity: Vector3,
	verticalVelocity: number,
	active: boolean,
	reaching: boolean?
): (CFrame, number, number)
	if rigState.sway == nil or not active then
		Balance.reset(rigState)
		if not active then
			return CFrame.identity, 1, 0
		end
	end
	dt = math.clamp(dt, 1 / 240, 1 / 30)
	local gravity = Workspace.Gravity
	local facing = CFrame.Angles(0, rigState.facingYaw, 0)

	-- How the body is actually speeding up or slowing down, smoothed so contact
	-- jitter doesn't shake the torso.
	local lastVelocity = rigState.balanceLastVelocity or flatVelocity
	rigState.balanceLastVelocity = flatVelocity
	local rawAcceleration = (flatVelocity - lastVelocity) / dt
	if rawAcceleration.Magnitude > gravity * 2 then
		rawAcceleration = rawAcceleration.Unit * gravity * 2
	end
	local blend = 1 - math.exp(-dt * Config.BalanceAccelSmoothing)
	rigState.smoothedAcceleration = rigState.smoothedAcceleration:Lerp(rawAcceleration, blend)

	local target = Vector3.zero
	local gripTarget = 1
	local legs = rigState.ikLegs
	local stepping = grounded and rigState.ikActive and legs ~= nil

	if grounded then
		-- Lean into acceleration like a real body has to (an inverted pendulum
		-- tilts by about a/g), plus a small lean into steady walking.
		-- (Not while the arms are up: they shove the body around and that would
		-- feed back into the sway and shake it.)
		if not reaching then
			target += rigState.smoothedAcceleration / gravity * Config.BalanceAccelLean
		end
		if moveDirection.Magnitude > 0.1 then
			target += flatVelocity / Config.WalkSpeed * math.rad(Config.LeanAngle)
		end
		-- Arms up: lean the torso a bit forward to counter the pull of the arms.
		if reaching then
			target += facing.LookVector * math.rad(Config.ReachLean)
		end

		-- Weight over the planted foot while the other one is in the air.
		if stepping then
			for _, leg in legs do
				if leg.stepping then
					target += facing.RightVector * (-leg.sideSign * math.rad(Config.WeightShiftAngle))
				end
			end
		end

		-- Landing: the knees give and the torso pitches with the momentum.
		-- A big drop knocks you flat; a hard one while moving makes you stumble.
		if not rigState.wasGrounded then
			local landingSpeed = math.max(rigState.fallSpeed, -verticalVelocity)
			if landingSpeed > Config.HardLandingKnockSpeed then
				Knockdown.knockDown(rigState)
			elseif landingSpeed > Config.HardLandingSpeed and flatVelocity.Magnitude > 3 then
				Knockdown.stagger(rigState, flatVelocity, math.rad(Config.HardLandingTilt))
			end
			local impact = landingSpeed - Config.LandingMinSpeed
			if impact > 0 then
				rigState.heightVelocity -= impact * Config.LandingSquash
				local kick = math.min(impact / 20, 1) * Config.LandingSwayKick
				rigState.swayVelocity += flatVelocity / Config.WalkSpeed * kick
			end
		end
		rigState.fallSpeed = 0
		rigState.airTime = 0
	else
		rigState.airTime += dt
		rigState.fallSpeed = math.max(rigState.fallSpeed, -verticalVelocity)
		-- Short hops keep most of the balance; longer falls lose it.
		gripTarget = math.max(Config.AirBalance, 1 - rigState.airTime / Config.AirBalanceFade)
	end
	rigState.wasGrounded = grounded

	-- The grip comes back gradually after landing instead of snapping upright.
	local gripRate = if gripTarget > rigState.balanceGrip then Config.BalanceRegrip else 20
	rigState.balanceGrip += (gripTarget - rigState.balanceGrip) * (1 - math.exp(-dt * gripRate))

	local maxSway = math.rad(Config.BalanceSwayMax)
	if target.Magnitude > maxSway then
		target = target.Unit * maxSway
	end
	local sway, swayVelocity = spring(
		rigState.sway,
		rigState.swayVelocity,
		target,
		Config.BalanceSwayFrequency,
		if reaching then Config.ReachSwayDamping else Config.BalanceSwayDamping,
		dt
	)
	if sway.Magnitude > maxSway then
		sway = sway.Unit * maxSway
		swayVelocity -= sway.Unit * math.max(swayVelocity:Dot(sway.Unit), 0)
	end
	rigState.sway, rigState.swayVelocity = sway, swayVelocity

	-- Hips drop when the feet are spread mid-stride and rise as they pass.
	local heightTarget = 0
	if stepping and legs.Left and legs.Right then
		local apart = legs.Left.foot.Position - legs.Right.foot.Position
		local stride = math.abs(facing.LookVector:Dot(apart))
		heightTarget = -Config.GaitBob * math.clamp(stride / (2 * Config.StepDistance), 0, 1)
	end
	local height, heightVelocity = spring(
		rigState.heightOffset,
		rigState.heightVelocity,
		heightTarget,
		Config.HeightSpringFrequency,
		Config.HeightSpringDamping,
		dt
	)
	-- Getting up: rise out of a crouch instead of being lifted straight up.
	if rigState.state == "Recovering" then
		local progress = math.clamp(rigState.stateTime / Config.RecoverTime, 0, 1)
		local eased = progress * progress * (3 - 2 * progress)
		height = -(1 - eased) * rigState.standHeight * Config.GetUpCrouch
		heightVelocity = 0
	elseif height < -Config.LandingSquashMax then
		height = -Config.LandingSquashMax
		heightVelocity = math.max(heightVelocity, 0)
	end
	rigState.heightOffset, rigState.heightVelocity = height, heightVelocity

	local tilt = CFrame.identity
	if sway.Magnitude > 1e-4 then
		tilt = CFrame.fromAxisAngle(Vector3.yAxis:Cross(sway.Unit), sway.Magnitude)
	end
	return tilt, rigState.balanceGrip, height
end

return Balance
