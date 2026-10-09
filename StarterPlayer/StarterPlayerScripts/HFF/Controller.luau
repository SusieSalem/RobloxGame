-- Controller
-- Runs every physics step for the local character: balance, walking, the
-- stand spring, jumping, legs, arms and grabbing, then the reactions.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)
local Input = require(script.Parent.Input)
local Drives = require(script.Parent.Drives)
local Knockdown = require(script.Parent.Knockdown)
local Grab = require(script.Parent.Grab)
local LegIK = require(script.Parent.LegIK)
local Reactions = require(script.Parent.Reactions)

local Config = Shared.Config
local State = Shared.State

local TAU = math.pi * 2

local Controller = {}

local function jump(rigState)
	local seen = {}
	for _, part in rigState.bodyParts do
		local assemblyRoot = part.AssemblyRootPart
		if assemblyRoot and not seen[assemblyRoot] then
			seen[assemblyRoot] = true
			local v = assemblyRoot.AssemblyLinearVelocity
			assemblyRoot.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + Config.JumpVelocity, v.Z)
		end
	end
	rigState.skipImpactCheck = true
end

function Controller.step(dt: number)
	local rigState = State.rig
	if not rigState or rigState.state == "Dead" or not rigState.character.Parent then
		State.jumpQueued = false
		return
	end
	local now = os.clock()
	local humanoid = rigState.humanoid
	local root = rigState.root
	local core = rigState.core

	-- Keep the Humanoid out of the way: no walking, no auto get-up.
	if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	rigState.stateTime += dt
	Knockdown.update(rigState, dt, now)

	local balanceScale = Knockdown.updateStagger(rigState, dt, now, Input.getMoveDirection())

	local active = rigState.state ~= "Knocked"
	local strength = 1
	if rigState.state == "Recovering" then
		strength = math.clamp(rigState.stateTime / Config.RecoverTime, 0.05, 1)
		if rigState.stateTime >= Config.RecoverTime then
			rigState.state = "Active"
			rigState.stateTime = 0
		end
	end

	local moveDirection = Input.getMoveDirection()
	local staggering = rigState.state == "Stagger"
	if staggering then
		-- Catch-steps: walk toward where the body is tipping to get the feet under it.
		local drift = rigState.teeterDrift
		moveDirection = if drift.Magnitude > 1e-3
			then drift.Unit * math.clamp(drift.Magnitude * Config.StaggerTravel, 0, 0.45)
			else Vector3.zero
	end
	local leftHeld = Input.isArmHeld("Left")
	local rightHeld = Input.isArmHeld("Right")
	local reaching = leftHeld or rightHeld

	-- Ground probe from the root straight down.
	-- Start a bit above the root so the probe still finds the floor if the body sank into it.
	local ground = Workspace:Raycast(
		root.Position + Vector3.new(0, 2, 0),
		Vector3.new(0, -(rigState.standHeight + Config.GroundProbeExtra + 2), 0),
		rigState.raycastParams
	)
	local grounded = ground ~= nil
	if grounded then
		rigState.lastGroundedTime = now
	end

	-- Facing: toward the camera while reaching (so you can aim), else toward movement.
	if reaching then
		rigState.facingYaw = Util.getCameraYaw()
	elseif moveDirection.Magnitude > 0.1 and not staggering then
		rigState.facingYaw = Util.yawFromDirection(moveDirection)
	end

	local velocity = core.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speedAlpha = math.clamp(flatVelocity.Magnitude / Config.WalkSpeed, 0, 1)

	-- Balance: soft upright target, leaning into the walk.
	local lean = if moveDirection.Magnitude > 0.1 then math.rad(Config.LeanAngle) * speedAlpha else 0
	local tip = CFrame.identity
	if staggering and rigState.teeterDrift.Magnitude > 1e-3 then
		local drift = rigState.teeterDrift
		tip = CFrame.fromAxisAngle(Vector3.yAxis:Cross(drift.Unit), drift.Magnitude)
	end
	rigState.balance.CFrame = tip * CFrame.Angles(0, rigState.facingYaw, 0) * CFrame.Angles(-lean, 0, 0)
	rigState.balance.Enabled = active
	rigState.balance.MaxTorque = Config.BalanceMaxTorque * strength * balanceScale
	rigState.balance.Responsiveness = math.max(Config.BalanceResponsiveness * strength, 5)

	-- Forces: walk velocity controller + stand spring.
	local force = Vector3.zero
	if active then
		local mass = rigState.totalMass
		local control = if grounded then 1 else Config.AirControl
		local desired = moveDirection * Config.WalkSpeed
		local acceleration = (desired - flatVelocity) * Config.WalkAcceleration * control
		if not grounded and moveDirection.Magnitude < 0.05 then
			acceleration = Vector3.zero -- keep momentum in the air
		end
		local maxAcceleration = Config.WalkMaxAcceleration * control
		if acceleration.Magnitude > maxAcceleration then
			acceleration = acceleration.Unit * maxAcceleration
		end
		force += acceleration * mass * strength

		if ground and now - rigState.lastJumpTime > Config.JumpHoverGrace then
			local height = root.Position.Y - ground.Position.Y
			local up = Workspace.Gravity
				+ (rigState.standHeight - height) * Config.HoverStiffness
				- velocity.Y * Config.HoverDamping
			up = math.clamp(up, 0, Config.HoverMaxAcceleration) * strength
			force += Vector3.new(0, up * mass, 0)
		end
	end
	rigState.force.Force = force

	if Config.Debug and now - (rigState.lastDebugTime or 0) > 1 then
		rigState.lastDebugTime = now
		print(string.format(
			"[HFF] state=%s grounded=%s height=%.2f target=%.2f mass=%.1f force=%s",
			rigState.state,
			tostring(grounded),
			if ground then root.Position.Y - ground.Position.Y else -1,
			rigState.standHeight,
			rigState.totalMass,
			tostring(force)
		))
	end

	-- Jump. The default controls (mobile jump button, gamepad A) set Humanoid.Jump.
	if humanoid.Jump then
		humanoid.Jump = false
		State.jumpQueued = true
	end
	if State.jumpQueued then
		State.jumpQueued = false
		if
			rigState.state == "Active"
			and now - rigState.lastGroundedTime <= Config.CoyoteTime
			and now - rigState.lastJumpTime >= Config.JumpCooldown
		then
			rigState.lastJumpTime = now
			jump(rigState)
		end
	end

	-- Legs: IK foot placement on the ground, or the simple stride as a fallback.
	local walking = active and grounded and speedAlpha > 0.15 and moveDirection.Magnitude > 0.1
	local swing
	if Config.LegIK and rigState.ikLegs and active and grounded then
		local landed = LegIK.update(rigState, dt, flatVelocity, strength)
		swing = rigState.ikSwing
		-- Each catch-step while stumbling wins back some balance.
		if landed > 0 and rigState.state == "Stagger" then
			rigState.teeterDrift *= (1 - Config.StepBalanceRecovery)
		end
	else
		rigState.ikActive = false
		if walking then
			rigState.stepPhase = (rigState.stepPhase + dt * Config.StepFrequency * TAU * (0.5 + 0.5 * speedAlpha)) % TAU
		end
		local amount = if walking then speedAlpha else 0
		swing = math.sin(rigState.stepPhase) * math.rad(Config.StrideAngle) * amount
		local kneeLeft = math.max(0, math.cos(rigState.stepPhase)) * math.rad(Config.KneeBendAngle) * amount
		local kneeRight = math.max(0, -math.cos(rigState.stepPhase)) * math.rad(Config.KneeBendAngle) * amount
		local legs = rigState.legDrives
		Drives.set(legs.LeftHip, swing, strength, active)
		Drives.set(legs.RightHip, -swing, strength, active)
		Drives.set(legs.LeftKnee, -kneeLeft, strength, active)
		Drives.set(legs.RightKnee, -kneeRight, strength, active)
	end
	Drives.set(rigState.headDrive, 0, strength, active)

	-- Arms: raise toward where the camera looks (tilted up by ArmRaiseAngle),
	-- then grab on contact.
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local lookYaw = Util.yawFromDirection(look)
	local lookPitch = math.asin(math.clamp(look.Y, -1, 1))
	local aimPitch = math.clamp(lookPitch + math.rad(Config.ArmRaiseAngle), math.rad(-80), math.rad(85))
	local aim = Vector3.new(
		-math.sin(lookYaw) * math.cos(aimPitch),
		math.sin(aimPitch),
		-math.cos(lookYaw) * math.cos(aimPitch)
	)
	local right = core.CFrame.RightVector
	local armUp = right - aim * aim:Dot(right)
	if armUp.Magnitude < 1e-3 then
		armUp = core.CFrame.UpVector
	end
	local reachFrame = CFrame.fromMatrix(Vector3.zero, aim, armUp.Unit)

	for side, arm in rigState.arms do
		local held = if side == "Left" then leftHeld else rightHeld
		local raise = held and active
		-- Walk swing: left arm moves with the right leg and vice versa.
		local armSwing = if side == "Left" then -swing else swing
		Drives.set(rigState.armSwingDrives[side], armSwing * Config.ArmSwingScale, strength, active and (walking or rigState.ikActive) and not raise)
		if arm.upper then
			arm.upper.Enabled = raise
			arm.upper.CFrame = reachFrame
		end
		if arm.lower then
			arm.lower.Enabled = raise
			arm.lower.CFrame = reachFrame
		end
		Grab.update(rigState, arm, held, now)
	end

	Reactions.apply(rigState, dt, velocity, grounded, reaching)
end

return Controller
