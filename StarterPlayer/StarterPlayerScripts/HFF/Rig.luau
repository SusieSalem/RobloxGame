-- Rig
-- Builds (and tears down) the per-character controller state: balance,
-- movement force, joint drives, arm reach aligns and leg IK data.

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)
local Drives = require(script.Parent.Drives)

local Config = Shared.Config
local player = Shared.Player

local makeDrive = Drives.make
local makeArmAlign = Drives.makeArmAlign
local yawFromDirection = Util.yawFromDirection

local Rig = {}

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

function Rig.build(character: Model)
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
		reactionTime = 0,
		teeterDrift = Vector3.zero, -- how far (radians) and which way the body is tipping while staggering
		teeterManual = false,
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
	rigState.elbowDrives = {
		Left = makeDrive(rigState, "LeftElbow", Config.EuphoriaFlailTorque, Config.LegResponsiveness),
		Right = makeDrive(rigState, "RightElbow", Config.EuphoriaFlailTorque, Config.LegResponsiveness),
	}
	for _, drive in rigState.elbowDrives do
		drive.align.Enabled = false
	end
	-- Shoulders swing opposite the legs while walking (when not reaching).
	rigState.armSwingDrives = {
		Left = makeDrive(rigState, "LeftShoulder", Config.ArmSwingMaxTorque, Config.LegResponsiveness),
		Right = makeDrive(rigState, "RightShoulder", Config.ArmSwingMaxTorque, Config.LegResponsiveness),
	}

	-- Leg IK data: segment lengths and where each foot is planted.
	rigState.ikLegs = {}
	for _, side in { "Left", "Right" } do
		local hip = rigState.joints[side .. "Hip"]
		local knee = rigState.joints[side .. "Knee"]
		local foot = character:FindFirstChild(side .. "Foot")
		local lowerLeg = character:FindFirstChild(side .. "LowerLeg")
		local shinAnkle = lowerLeg and lowerLeg:FindFirstChild(side .. "AnkleRigAttachment")
		local footAnkle = foot and foot:FindFirstChild(side .. "AnkleRigAttachment")
		local hipDrive = rigState.legDrives[side .. "Hip"]
		local kneeDrive = rigState.legDrives[side .. "Knee"]
		if hip and knee and foot and shinAnkle and footAnkle and hipDrive and kneeDrive then
			rigState.ikLegs[side] = {
				side = side,
				sideSign = if side == "Left" then -1 else 1,
				spacing = math.abs(hip.a0.Position.X),
				hipJoint = hip,
				hipDrive = hipDrive,
				kneeDrive = kneeDrive,
				foot = foot,
				thigh = (hip.a1.Position - knee.a0.Position).Magnitude,
				shin = (knee.a1.Position - shinAnkle.Position).Magnitude + footAnkle.Position.Y + foot.Size.Y / 2,
				planted = foot.Position,
				stepping = false,
				t = 0,
			}
		else
			rigState.ikLegs = nil
			warn("[HFF] Leg IK disabled: missing leg joints or ankle attachments")
			break
		end
	end
	rigState.ikActive = false
	rigState.ikSwing = 0

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

function Rig.destroy(rigState)
	for _, connection in rigState.connections do
		connection:Disconnect()
	end
	for _, instance in rigState.instances do
		instance:Destroy()
	end
end

return Rig
