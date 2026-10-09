-- HFFClient
-- Human Fall Flat style controller for the local R15 character.
--
-- The server turns the character into a ragdoll and gives this client network
-- ownership, so every force and drive constraint here is created locally and
-- the resulting motion replicates to everyone else.
--
-- Controls: WASD move, Space jump, hold Left/Right mouse to reach with the
-- left/right arm (hands grip whatever they touch). The camera is the normal
-- Roblox camera; arms reach where it looks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("HFFMovementConfig"))
if Config.Version ~= 2 then
	warn("[HFF] HFFMovementConfig is out of date; sync ReplicatedStorage/HFFMovementConfig.luau again")
end
local remotes = ReplicatedStorage:WaitForChild("HFFRemotes")
local grabRemote = remotes:WaitForChild("Grab") :: RemoteEvent
local knockdownRemote = remotes:WaitForChild("Knockdown") :: RemoteEvent

local player = Players.LocalPlayer

local GRIP_NAME = "HFFGrip"
local TAU = math.pi * 2

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------


local jumpQueued = false

-- The current character's controller (built by buildRig, nil while dead/loading).
local rig = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function closestPointOnPart(part: BasePart, point: Vector3): Vector3
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return part.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	))
end

local function yawFromDirection(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- Yaw of the default Roblox camera, used for camera-relative movement and aiming.
local function getCameraYaw(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	return yawFromDirection(camera.CFrame.LookVector)
end

local function getMoveDirection(): Vector3
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		z -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		z += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	local input = Vector3.new(x, 0, z)
	if input.Magnitude == 0 then
		return Vector3.zero
	end
	return CFrame.Angles(0, getCameraYaw(), 0):VectorToWorldSpace(input.Unit)
end

local function isArmHeld(side: string): boolean
	if side == "Left" then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
	end
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
end

---------------------------------------------------------------------------
-- Rig construction
---------------------------------------------------------------------------

-- A drive bends a ball-socket joint toward an angle relative to its parent
-- part by moving a target attachment that the child's attachment chases.
local function makeDrive(rigState, jointName: string, maxTorque: number, responsiveness: number)
	local joint = rigState.joints[jointName]
	if not joint then
		return nil
	end
	local target = Instance.new("Attachment")
	target.Name = "HFFDriveTarget_" .. jointName
	target.CFrame = joint.a0.CFrame
	target.Parent = joint.part0

	local align = Instance.new("AlignOrientation")
	align.Name = "HFFDrive_" .. jointName
	align.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	align.Attachment0 = joint.a1
	align.Attachment1 = target
	align.MaxTorque = maxTorque
	align.Responsiveness = responsiveness
	align.Parent = joint.part1

	table.insert(rigState.instances, target)
	table.insert(rigState.instances, align)
	return { align = align, target = target, base = joint.a0.CFrame, maxTorque = maxTorque }
end

-- Joint frames have X along the limb and Y along the body's right axis, so a
-- positive angle about Y swings the limb forward.
local function setDrive(drive, angle: number, strength: number, enabled: boolean)
	if not drive then
		return
	end
	drive.align.Enabled = enabled and strength > 0
	drive.align.MaxTorque = drive.maxTorque * strength
	drive.target.CFrame = drive.base * CFrame.Angles(0, angle, 0)
end

-- Arms aim in world space, so they use one-attachment AlignOrientations.
local function makeArmAlign(rigState, jointName: string)
	local joint = rigState.joints[jointName]
	if not joint then
		return nil
	end
	local align = Instance.new("AlignOrientation")
	align.Name = "HFFReach_" .. jointName
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = joint.a1
	align.MaxTorque = Config.ArmMaxTorque
	align.Responsiveness = Config.ArmResponsiveness
	align.MaxAngularVelocity = Config.ArmMaxAngularVelocity
	align.Enabled = false
	align.Parent = joint.part1
	table.insert(rigState.instances, align)
	return align
end

local function waitForReady(character: Model): boolean
	local deadline = os.clock() + 15
	while not character:GetAttribute("HFFReady") do
		if os.clock() > deadline or player.Character ~= character then
			return false
		end
		task.wait(0.1)
	end
	return true
end

local function buildRig(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	if not waitForReady(character) then
		warn("[HFF] Character never became ready; is HFFServer running?")
		return nil
	end

	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local core = character:WaitForChild("UpperTorso") :: BasePart

	-- Make sure nothing animates the joints we kept rigid.
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = false
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end

	-- Normal Roblox camera following this character.
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid

	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local rigState = {
		character = character,
		humanoid = humanoid,
		root = root,
		core = core,
		joints = {},
		instances = {},
		connections = {},
		bodyParts = {},
		totalMass = 0,
		standHeight = (humanoid.HipHeight + root.Size.Y / 2) * Config.StandHeightScale,
		facingYaw = yawFromDirection(root.CFrame.LookVector),
		stepPhase = 0,
		lastGroundedTime = 0,
		lastJumpTime = 0,
		lastVelocity = Vector3.zero,
		skipImpactCheck = true,
		tiltTimer = 0,
		state = "Active",
		stateTime = 0,
		knockDuration = Config.KnockdownTime,
		graceUntil = os.clock() + Config.RecoverGrace,
		arms = {},
	}

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			table.insert(rigState.bodyParts, part)
			if not part.Massless then
				rigState.totalMass += part:GetMass()
			end
		end
	end

	-- Find the ball sockets the server built in place of the Motor6Ds.
	local jointCount = 0
	for _, socket in character:GetDescendants() do
		if socket:IsA("BallSocketConstraint") and socket.Name:sub(1, 10) == "HFFSocket_" then
			local a0, a1 = socket.Attachment0, socket.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent then
				rigState.joints[socket.Name:sub(11)] = { part0 = a0.Parent, part1 = a1.Parent, a0 = a0, a1 = a1 }
				jointCount += 1
			end
		end
	end
	if jointCount == 0 then
		warn("[HFF] No ragdoll joints found on the character; arms and legs won't move")
	end

	-- Balance + movement forces live on the root (rigidly welded to the torso).
	local coreAttachment = Instance.new("Attachment")
	coreAttachment.Name = "HFFCore"
	coreAttachment.Parent = root
	table.insert(rigState.instances, coreAttachment)

	local balance = Instance.new("AlignOrientation")
	balance.Name = "HFFBalance"
	balance.Mode = Enum.OrientationAlignmentMode.OneAttachment
	balance.Attachment0 = coreAttachment
	balance.MaxTorque = Config.BalanceMaxTorque
	balance.Responsiveness = Config.BalanceResponsiveness
	balance.MaxAngularVelocity = Config.BalanceMaxAngularVelocity
	balance.CFrame = CFrame.Angles(0, rigState.facingYaw, 0)
	balance.Parent = root
	table.insert(rigState.instances, balance)
	rigState.balance = balance

	local force = Instance.new("VectorForce")
	force.Name = "HFFMoveForce"
	force.Attachment0 = coreAttachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Parent = root
	table.insert(rigState.instances, force)
	rigState.force = force

	rigState.legDrives = {
		LeftHip = makeDrive(rigState, "LeftHip", Config.LegMaxTorque, Config.LegResponsiveness),
		RightHip = makeDrive(rigState, "RightHip", Config.LegMaxTorque, Config.LegResponsiveness),
		LeftKnee = makeDrive(rigState, "LeftKnee", Config.LegMaxTorque, Config.LegResponsiveness),
		RightKnee = makeDrive(rigState, "RightKnee", Config.LegMaxTorque, Config.LegResponsiveness),
	}
	rigState.headDrive = makeDrive(rigState, "Neck", Config.HeadMaxTorque, Config.HeadResponsiveness)
	-- Shoulders swing opposite the legs while walking (when not reaching).
	rigState.armSwingDrives = {
		Left = makeDrive(rigState, "LeftShoulder", Config.ArmSwingMaxTorque, Config.LegResponsiveness),
		Right = makeDrive(rigState, "RightShoulder", Config.ArmSwingMaxTorque, Config.LegResponsiveness),
	}

	for _, side in { "Left", "Right" } do
		local hand = character:FindFirstChild(side .. "Hand")
		if hand then
			rigState.arms[side] = {
				side = side,
				hand = hand,
				upper = makeArmAlign(rigState, side .. "Shoulder"),
				lower = makeArmAlign(rigState, side .. "Elbow"),
				nextGrabTime = 0,
				requested = false,
				lastReleaseTime = 0,
			}
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	rigState.raycastParams = raycastParams

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = 16
	rigState.overlapParams = overlapParams

	table.insert(rigState.connections, humanoid.Died:Connect(function()
		rigState.state = "Dead"
		balance.Enabled = false
		force.Force = Vector3.zero
		for _, instance in rigState.instances do
			if instance:IsA("AlignOrientation") then
				instance.Enabled = false
			end
		end
	end))

	return rigState
end

local function destroyRig(rigState)
	for _, connection in rigState.connections do
		connection:Disconnect()
	end
	for _, instance in rigState.instances do
		instance:Destroy()
	end
end

---------------------------------------------------------------------------
-- Knockdown
---------------------------------------------------------------------------

local function knockDown(rigState, duration: number?)
	if rigState.state == "Dead" then
		return
	end
	rigState.state = "Knocked"
	rigState.stateTime = 0
	rigState.knockDuration = duration or Config.KnockdownTime
	rigState.tiltTimer = 0
end

local function updateKnockdown(rigState, dt: number, now: number)
	local velocity = rigState.core.AssemblyLinearVelocity
	local velocityChange = (velocity - rigState.lastVelocity).Magnitude
	rigState.lastVelocity = velocity
	if rigState.skipImpactCheck then
		rigState.skipImpactCheck = false
		velocityChange = 0
	end

	if rigState.state == "Knocked" then
		if rigState.stateTime >= rigState.knockDuration then
			rigState.state = "Recovering"
			rigState.stateTime = 0
			rigState.graceUntil = now + Config.RecoverGrace
		end
		return
	end
	if now < rigState.graceUntil then
		rigState.tiltTimer = 0
		return
	end

	if velocityChange > Config.ImpactKnockdownSpeed then
		knockDown(rigState)
		return
	end

	local upright = rigState.core.CFrame.UpVector.Y
	if upright < math.cos(math.rad(Config.FallTiltAngle)) then
		rigState.tiltTimer += dt
		if rigState.tiltTimer > Config.FallTiltTime then
			knockDown(rigState)
		end
	else
		rigState.tiltTimer = 0
	end
end

---------------------------------------------------------------------------
-- Grabbing (the server creates the actual grip so everyone sees it)
---------------------------------------------------------------------------

local function findGrabTarget(rigState, hand: BasePart): (BasePart?, Vector3?)
	local best: BasePart? = nil
	local bestPoint: Vector3? = nil
	local bestDistance = math.huge
	for _, part in Workspace:GetPartBoundsInRadius(hand.Position, Config.GrabRadius, rigState.overlapParams) do
		if part:GetAttribute("HFFNoGrab") or (part.Parent and part.Parent:IsA("Accessory")) then
			continue
		end
		if not part.CanCollide then
			continue
		end
		local point = closestPointOnPart(part, hand.Position)
		local distance = (point - hand.Position).Magnitude
		if distance < bestDistance and distance <= Config.GrabRadius then
			best, bestPoint, bestDistance = part, point, distance
		end
	end
	return best, bestPoint
end

local function updateGrab(rigState, arm, held: boolean, now: number)
	local gripped = arm.hand:FindFirstChild(GRIP_NAME) ~= nil

	if not held then
		-- Re-send the release if a late grip arrives after we let go.
		if arm.requested or (gripped and now - arm.lastReleaseTime > 0.3) then
			grabRemote:FireServer("Release", arm.side)
			arm.requested = false
			arm.lastReleaseTime = now
		end
		return
	end

	if gripped or now < arm.nextGrabTime then
		return
	end
	local target, point = findGrabTarget(rigState, arm.hand)
	if target and point then
		grabRemote:FireServer("Grab", arm.side, target, point)
		arm.requested = true
		arm.nextGrabTime = now + Config.GrabRetryDelay
	end
end

---------------------------------------------------------------------------
-- Per-physics-step controller
---------------------------------------------------------------------------

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

local function step(dt: number)
	local rigState = rig
	if not rigState or rigState.state == "Dead" or not rigState.character.Parent then
		jumpQueued = false
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
	updateKnockdown(rigState, dt, now)

	local active = rigState.state ~= "Knocked"
	local strength = 1
	if rigState.state == "Recovering" then
		strength = math.clamp(rigState.stateTime / Config.RecoverTime, 0.05, 1)
		if rigState.stateTime >= Config.RecoverTime then
			rigState.state = "Active"
			rigState.stateTime = 0
		end
	end

	local moveDirection = getMoveDirection()
	local leftHeld = isArmHeld("Left")
	local rightHeld = isArmHeld("Right")
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
		rigState.facingYaw = getCameraYaw()
	elseif moveDirection.Magnitude > 0.1 then
		rigState.facingYaw = yawFromDirection(moveDirection)
	end

	local velocity = core.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speedAlpha = math.clamp(flatVelocity.Magnitude / Config.WalkSpeed, 0, 1)

	-- Balance: soft upright target, leaning into the walk.
	local lean = if moveDirection.Magnitude > 0.1 then math.rad(Config.LeanAngle) * speedAlpha else 0
	rigState.balance.CFrame = CFrame.Angles(0, rigState.facingYaw, 0) * CFrame.Angles(-lean, 0, 0)
	rigState.balance.Enabled = active
	rigState.balance.MaxTorque = Config.BalanceMaxTorque * strength
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

	-- Jump.
	if jumpQueued then
		jumpQueued = false
		if
			rigState.state == "Active"
			and now - rigState.lastGroundedTime <= Config.CoyoteTime
			and now - rigState.lastJumpTime >= Config.JumpCooldown
		then
			rigState.lastJumpTime = now
			jump(rigState)
		end
	end

	-- Legs: procedural stride while walking on the ground.
	local walking = active and grounded and speedAlpha > 0.15 and moveDirection.Magnitude > 0.1
	if walking then
		rigState.stepPhase = (rigState.stepPhase + dt * Config.StepFrequency * TAU * (0.5 + 0.5 * speedAlpha)) % TAU
	end
	local amount = if walking then speedAlpha else 0
	local swing = math.sin(rigState.stepPhase) * math.rad(Config.StrideAngle) * amount
	local kneeLeft = math.max(0, math.cos(rigState.stepPhase)) * math.rad(Config.KneeBendAngle) * amount
	local kneeRight = math.max(0, -math.cos(rigState.stepPhase)) * math.rad(Config.KneeBendAngle) * amount
	local legs = rigState.legDrives
	setDrive(legs.LeftHip, swing, strength, active)
	setDrive(legs.RightHip, -swing, strength, active)
	setDrive(legs.LeftKnee, -kneeLeft, strength, active)
	setDrive(legs.RightKnee, -kneeRight, strength, active)
	setDrive(rigState.headDrive, 0, strength, active)

	-- Arms: raise toward where the camera looks (tilted up by ArmRaiseAngle),
	-- then grab on contact.
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local lookYaw = yawFromDirection(look)
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
		setDrive(rigState.armSwingDrives[side], armSwing * Config.ArmSwingScale, strength, active and walking and not raise)
		if arm.upper then
			arm.upper.Enabled = raise
			arm.upper.CFrame = reachFrame
		end
		if arm.lower then
			arm.lower.Enabled = raise
			arm.lower.CFrame = reachFrame
		end
		updateGrab(rigState, arm, held, now)
	end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		jumpQueued = true
	end
end)

-- The Humanoid is in the Physics state, but stop the default controls from
-- reading WASD/Space anyway.
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and playerModule then
		playerModule:GetControls():Disable()
	end
end)

knockdownRemote.OnClientEvent:Connect(function(duration: number?)
	if rig then
		knockDown(rig, duration)
	end
end)

---------------------------------------------------------------------------
-- Character lifecycle
---------------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	if rig then
		destroyRig(rig)
		rig = nil
	end
	local rigState = buildRig(character)
	if rigState and player.Character == character and character.Parent then
		rig = rigState
		local count = 0
		for _ in rigState.joints do
			count += 1
		end
		print(string.format("[HFF] Controller active on %s (%d joints)", character.Name, count))
	elseif rigState then
		destroyRig(rigState)
	end
end

print("[HFF] Client running")

local oldController = player:WaitForChild("PlayerScripts"):FindFirstChild("HFFMovementController", true)
if oldController then
	warn("[HFF] Old script still in the game, delete it: " .. oldController:GetFullName())
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService.PreSimulation:Connect(step)
