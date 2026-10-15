-- Controller
-- Runs every physics step for the local character: balance, walking, the
-- stand spring, jumping, legs, arms and grabbing, then the reactions.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)
local Input = require(script.Parent.Input)
local Drives = require(script.Parent.Drives)
local Balance = require(script.Parent.Balance)
local Knockdown = require(script.Parent.Knockdown)
local Grab = require(script.Parent.Grab)
local LegIK = require(script.Parent.LegIK)
local Reactions = require(script.Parent.Reactions)
local DebugOverlay = require(script.Parent.DebugOverlay)

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

	-- Dying must not be overridden: forcing Physics on a dead Humanoid stops
	-- the death (and so the respawn) from ever registering.
	if humanoid.Health <= 0 then
		if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
		rigState.force.Force = Vector3.zero
		rigState.balance.Enabled = false
		for _, arm in rigState.arms do
			arm.drag.Force = Vector3.zero
		end
		return
	end

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
		-- Muscles come back slowly at first, then firmly (no snap upright).
		local progress = math.clamp(rigState.stateTime / Config.RecoverTime, 0, 1)
		strength = math.max(progress * progress * (3 - 2 * progress), 0.05)
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

	-- Balance: a springy, weighted sway (see Balance) instead of a rigid upright.
	local sway, grip, heightOffset = Balance.update(rigState, dt, grounded, moveDirection, flatVelocity, velocity.Y, active, reaching)
	local tip = CFrame.identity
	if staggering and rigState.teeterDrift.Magnitude > 1e-3 then
		local drift = rigState.teeterDrift
		tip = CFrame.fromAxisAngle(Vector3.yAxis:Cross(drift.Unit), drift.Magnitude)
	end
	-- Walking twist: the shoulders turn a little left and right as you walk.
	-- Nothing pushes the boneless arms; they hang from the shoulders and get
	-- thrown around by this and by the sway above.
	local twistAmount = if active and grounded and not staggering and not reaching then speedAlpha else 0
	rigState.armPhase = (rigState.armPhase + dt * TAU * Config.WalkTwistFrequency * (0.5 + 0.5 * speedAlpha)) % TAU
	local twist = math.sin(rigState.armPhase) * math.rad(Config.WalkTwistAngle) * twistAmount
	rigState.balance.CFrame = tip * sway * CFrame.Angles(0, rigState.facingYaw + twist, 0)
	rigState.balance.Enabled = active
	local reachBoost = if reaching then Config.ReachBalanceBoost else 1
	rigState.balance.MaxTorque = Config.BalanceMaxTorque * strength * balanceScale * grip * reachBoost
	rigState.balance.Responsiveness = math.max(Config.BalanceResponsiveness * strength, 5)
	rigState.balance.MaxAngularVelocity = if rigState.state == "Recovering"
		then Config.GetUpTurnSpeed + (Config.BalanceMaxAngularVelocity - Config.GetUpTurnSpeed) * strength
		else Config.BalanceMaxAngularVelocity
	Knockdown.checkBalanceLoss(rigState, dt, now, rigState.balance.CFrame.UpVector, grounded and not reaching)

	local gripping = false
	for _, arm in rigState.arms do
		if Grab.isGripping(arm) then
			gripping = true
		end
	end
	local overloaded = false

	-- Forces: walk velocity controller + stand spring.
	local force = Vector3.zero
	if active then
		-- Leave out the weight the raised arms shed, or the legs would push
		-- the body up for weight that is no longer there.
		local mass = rigState.totalMass
		for _, arm in rigState.arms do
			if arm.light then
				mass -= arm.mass * (1 - Config.RaisedArmWeight)
			end
		end
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
				+ (rigState.standHeight + heightOffset - height) * Config.HoverStiffness
				- velocity.Y * Config.HoverDamping
			-- The legs push harder while carrying, so a load doesn't flatten you.
			local maxUp = Config.HoverMaxAcceleration * (if gripping then Config.CarryLegBoost else 1)
			-- Overloaded: the legs are maxed out or the body is being pressed down.
			overloaded = gripping
				and (up > maxUp or rigState.standHeight + heightOffset - height > Config.CarryMaxCrouch)
			up = math.clamp(up, 0, maxUp) * strength
			force += Vector3.new(0, up * mass, 0)

			-- For the on-screen readout (see the end of this function).
			rigState.debugPressed = rigState.standHeight - height
			rigState.debugLegPush = up
			rigState.debugLegMax = maxUp
		end
	end
	rigState.force.Force = force

	-- Lifting pushes the body down as hard as it pulls the load up. If the load
	-- is too heavy the arms ease off instead of crushing their own body into
	-- the floor (which is what made heavy lifts glitch), then try again.
	local armPower = rigState.armPower or 1
	armPower += if overloaded then -dt * Config.ArmGiveRate else dt * Config.ArmRecoverRate
	armPower = math.clamp(armPower, Config.ArmMinPower, 1)
	rigState.armPower = armPower

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
	-- Head: the neck keeps the eyes roughly level while the torso sways.
	-- (Off while the arms are up, so the raised arms can't set off the neck.)
	local stabilize = if reaching then 0 else Config.HeadStabilize
	local worldUp = core.CFrame:VectorToObjectSpace(Vector3.yAxis)
	Drives.pose(
		rigState.headDrive,
		-math.asin(math.clamp(worldUp.Z, -1, 1)) * stabilize,
		math.asin(math.clamp(worldUp.X, -1, 1)) * stabilize,
		if active then Config.HeadMaxTorque * strength else 0
	)

	-- Arms: always reach straight ahead of the torso. The camera only moves
	-- them up and down (tilted up by ArmRaiseAngle), never sideways or behind,
	-- so spinning the camera can't wrench the arms around and fold the body.
	-- Then grab on contact.
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local torsoLook = core.CFrame.LookVector
	local lookYaw = rigState.facingYaw
	if math.abs(torsoLook.Y) < 0.9 then
		-- The arms lead the turn a little: they point toward where the body is
		-- turning (the camera), but never more than ArmMaxYawLead away from
		-- the torso. That pulls the body, and whatever it holds, around with
		-- the camera without letting the arms reach sideways or behind.
		local torsoYaw = Util.yawFromDirection(torsoLook)
		local turn = (rigState.facingYaw - torsoYaw + math.pi) % TAU - math.pi
		local lead = math.rad(Config.ArmMaxYawLead)
		lookYaw = torsoYaw + math.clamp(turn, -lead, lead)
	end
	local lookPitch = math.asin(math.clamp(look.Y, -1, 1))
	-- Not all the way up: straight overhead the arm is jammed against the
	-- shoulder's limit (and the head), and the joint fights itself.
	local aimPitch = math.clamp(lookPitch + math.rad(Config.ArmRaiseAngle), math.rad(-80), math.rad(Config.ArmMaxPitch))
	local aim = Vector3.new(
		-math.sin(lookYaw) * math.cos(aimPitch),
		math.sin(aimPitch),
		-math.cos(lookYaw) * math.cos(aimPitch)
	)
	-- The arm's sideways axis comes from the aim direction alone, not from the
	-- torso, so a swaying or tilting torso can't feed back into the arms.
	local right = Vector3.new(math.cos(lookYaw), 0, -math.sin(lookYaw))
	local reachFrame = CFrame.fromMatrix(Vector3.zero, aim, right)

	local armReaction = Vector3.zero -- what the airborne arm forces add up to
	for side, arm in rigState.arms do
		local held = if side == "Left" then leftHeld else rightHeld
		local raise = held and active
		-- Raised arms are made light. Two heavy arms held out front sit high on
		-- the body like a top-heavy weight and set the balance wobbling. The
		-- arms' strength doesn't depend on their weight, so lifting is the
		-- same; hanging arms get their normal weight back for a natural swing.
		if raise ~= arm.light then
			arm.light = raise
			for _, entry in arm.parts do
				entry.part.CustomPhysicalProperties = if raise then entry.light else entry.normal
			end
		end
		-- The shoulder is never held by a drive: the arm hangs as a free
		-- pendulum and is only pushed around by forces, like a floppy thing.
		Drives.set(rigState.armSwingDrives[side], 0, 0, false)

		local dragForce = Vector3.zero
		if not raise then
			local handVelocity = arm.hand:GetVelocityAtPosition(arm.hand.Position)
			if grounded then
				-- Air drag on the hand: the arm trails behind the body's motion.
				dragForce = -Vector3.new(
					handVelocity.X * Config.ArmAirDrag,
					handVelocity.Y * Config.ArmAirDragVertical,
					handVelocity.Z * Config.ArmAirDrag
				) * arm.mass
				local maxDrag = Config.ArmAirDragMax * Workspace.Gravity * arm.mass
				if dragForce.Magnitude > maxDrag then
					dragForce = dragForce.Unit * maxDrag
				end
			else
				-- Off the ground the arms float up and out. The pull fades as
				-- the hand nears its resting height (a bit above the shoulder),
				-- so the arm settles there instead of slamming into its limit,
				-- and its motion relative to the body is damped so it doesn't
				-- shake. The body gets the opposite push (below), so none of
				-- this slows the fall.
				local shoulderY = if arm.shoulderPivot then arm.shoulderPivot.WorldPosition.Y else core.Position.Y
				local restY = shoulderY + Config.ArmAirRaise * arm.length
				local pull = math.clamp((restY - arm.hand.Position.Y) / arm.length, 0, 1)
				dragForce = Vector3.new(0, Config.ArmAirLift * Workspace.Gravity * arm.mass * pull, 0)
					- (handVelocity - velocity) * (Config.ArmAirDamping * arm.mass)
				armReaction += dragForce
			end
		end
		arm.drag.Force = dragForce

		-- A weak elbow keeps the forearm loosely in line with the upper arm, so
		-- the arm flops as one noodle from the shoulder. Reaching aims it instead.
		Drives.pose(
			rigState.elbowDrives[side],
			math.rad(Config.ArmElbowBend),
			0,
			if active and not raise then Config.ArmElbowTorque * strength else 0
		)
		if arm.upper then
			arm.upper.Enabled = raise
			arm.upper.CFrame = reachFrame * arm.upperOffset
		end
		if arm.lower then
			arm.lower.Enabled = raise
			arm.lower.CFrame = reachFrame * arm.lowerOffset
		end
		Grab.update(rigState, arm, held, now)
	end
	-- The arms push off the body, not off thin air: the torso takes the equal
	-- and opposite force, so the character as a whole falls at full gravity.
	rigState.force.Force = force - armReaction

	Reactions.apply(rigState, dt, velocity, grounded, reaching)

	-- On-screen readout while an arm is held, to find out what moves the body.
	if Config.DebugOverlay and reaching then
		local tilt = math.deg(math.acos(math.clamp(root.CFrame.UpVector.Y, -1, 1)))
		local pressed = rigState.debugPressed or 0
		-- Biggest values of the last two seconds, so a wobble shows in a still picture.
		if now - (rigState.debugPeakTime or 0) > 2 then
			rigState.debugPeakTime = now
			rigState.debugTiltPeak, rigState.debugPressedPeak, rigState.debugPressedLow = tilt, pressed, pressed
		end
		rigState.debugTiltPeak = math.max(rigState.debugTiltPeak, tilt)
		rigState.debugPressedPeak = math.max(rigState.debugPressedPeak, pressed)
		rigState.debugPressedLow = math.min(rigState.debugPressedLow, pressed)

		if now - (rigState.debugShownTime or 0) > 0.2 then
			rigState.debugShownTime = now
			local torsoYaw = Util.yawFromDirection(torsoLook)
			local yawOff = math.deg((rigState.facingYaw - torsoYaw + math.pi) % TAU - math.pi)
			local lines = {
				string.format(
					"v%s state=%s reaction=%s grounded=%s stiffLegs=%s",
					tostring(Config.Version),
					rigState.state,
					tostring(rigState.reactionMode),
					tostring(grounded),
					tostring(rigState.legsKinematic)
				),
				string.format(
					"tilt=%.0f (max %.0f)  pressed=%.2f (%.2f..%.2f)  dip=%.2f  yawOff=%.0f  speed=%.1f",
					tilt,
					rigState.debugTiltPeak,
					pressed,
					rigState.debugPressedLow,
					rigState.debugPressedPeak,
					-heightOffset,
					yawOff,
					velocity.Magnitude
				),
				string.format(
					"legPush=%.0f/%.0f  armPower=%.2f  overloaded=%s  bodyMass=%.1f",
					rigState.debugLegPush or 0,
					rigState.debugLegMax or 0,
					rigState.armPower or 1,
					tostring(overloaded),
					rigState.totalMass
				),
			}
			for side, arm in rigState.arms do
				local grip = arm.hand:FindFirstChild(Shared.GRIP_NAME)
				local target = if grip and grip:IsA("Constraint") and grip.Attachment1 then grip.Attachment1.Parent else nil
				local targetText = "nothing"
				if target and target:IsA("BasePart") then
					local targetRoot = target.AssemblyRootPart
					targetText = string.format(
						"%s mass=%.1f lift=%s anchored=%s",
						target.Name,
						target.AssemblyMass,
						tostring(targetRoot ~= nil and targetRoot:FindFirstChild("HFFCarryLift") ~= nil),
						tostring(targetRoot ~= nil and targetRoot.Anchored)
					)
				end
				local armOff = if arm.shoulderPivot
					then math.deg(math.acos(math.clamp(
						arm.shoulderPivot.WorldCFrame.XVector:Dot((reachFrame * arm.upperOffset).XVector),
						-1,
						1
					)))
					else -1
				local function jointText(name: string): string
					local joint = rigState.joints[name]
					if not joint then
						return "-"
					end
					-- Bend away from the rest pose, and roll about the limb's own axis.
					local rel = joint.a0.WorldCFrame:ToObjectSpace(joint.a1.WorldCFrame)
					return string.format(
						"%.0f/%.0f",
						math.deg(math.acos(math.clamp(rel.XVector.X, -1, 1))),
						math.deg(math.atan2(rel.YVector.Z, rel.YVector.Y))
					)
				end
				table.insert(lines, string.format(
					"%s joints (bend/roll): shoulder=%s elbow=%s",
					side,
					jointText(side .. "Shoulder"),
					jointText(side .. "Elbow")
				))
				table.insert(lines, string.format(
					"%s arm: held=%s offAim=%.0f torque=%.0f grip=%s",
					side,
					tostring(if side == "Left" then leftHeld else rightHeld),
					armOff,
					if arm.upper then arm.upper.MaxTorque else 0,
					targetText
				))
			end
			DebugOverlay.show(table.concat(lines, "\n"))
		end
	elseif rigState.debugShownTime then
		rigState.debugShownTime = nil
		DebugOverlay.show(nil)
	end
end

return Controller
