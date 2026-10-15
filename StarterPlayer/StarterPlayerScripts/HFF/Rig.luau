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

-- Same as the server's joint frames: X along the limb.
local LIMB_AXIS = CFrame.Angles(0, 0, -math.pi / 2)

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
		armPhase = 0,
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

	-- Accessories (hats, hair, pets, old-style Hat objects too) must never
	-- collide or weigh anything. The server sets this as well; doing it here
	-- too means it holds on this client, which simulates the body, even if an
	-- accessory loads late or the server's change hasn't arrived yet.
	local function neutralizeAccessoryPart(item: Instance)
		if item:IsA("BasePart") and item:FindFirstAncestorWhichIsA("Accoutrement") then
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	for _, item in character:GetDescendants() do
		neutralizeAccessoryPart(item)
	end
	table.insert(rigState.connections, character.DescendantAdded:Connect(neutralizeAccessoryPart))

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
				rigState.joints[socket.Name:sub(11)] = { part0 = a0.Parent, part1 = a1.Parent, a0 = a0, a1 = a1, socket = socket }
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
		Left = makeDrive(rigState, "LeftElbow", Config.EuphoriaFlailTorque, Config.ArmElbowResponsiveness),
		Right = makeDrive(rigState, "RightElbow", Config.EuphoriaFlailTorque, Config.ArmElbowResponsiveness),
	}
	for _, drive in rigState.elbowDrives do
		drive.align.Enabled = false
	end
	-- Shoulder drives: normally off (arms hang freely), only the reactions use them.
	rigState.armSwingDrives = {
		Left = makeDrive(rigState, "LeftShoulder", Config.EuphoriaFlailTorque, Config.ArmSwingResponsiveness),
		Right = makeDrive(rigState, "RightShoulder", Config.EuphoriaFlailTorque, Config.ArmSwingResponsiveness),
	}
	for _, drive in rigState.armSwingDrives do
		drive.align.Enabled = false
	end

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
			-- Arm weight and length, for the floppy-arm forces below.
			local mass, length = 0, 0
			local armParts = {}
			for _, name in { side .. "UpperArm", side .. "LowerArm", side .. "Hand" } do
				local part = character:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					mass += part:GetMass()
					length += part.Size.Y
					-- Normal and "raised" weight, see the arm loop in Controller.
					local normal = part.CurrentPhysicalProperties
					table.insert(armParts, {
						part = part,
						normal = normal,
						light = PhysicalProperties.new(
							normal.Density * Config.RaisedArmWeight,
							normal.Friction,
							normal.Elasticity,
							normal.FrictionWeight,
							normal.ElasticityWeight
						),
					})
				end
			end

			-- Air drag pulls on the hand, so the limp arm trails behind the body:
			-- it lifts while you fall and streams back when you move fast.
			local dragAttachment = Instance.new("Attachment")
			dragAttachment.Name = "HFFArmDrag"
			dragAttachment.Parent = hand
			table.insert(rigState.instances, dragAttachment)
			local drag = Instance.new("VectorForce")
			drag.Name = "HFFArmDrag"
			drag.Attachment0 = dragAttachment
			drag.RelativeTo = Enum.ActuatorRelativeTo.World
			drag.Force = Vector3.zero
			drag.Parent = hand
			table.insert(rigState.instances, drag)

			local elbow = rigState.joints[side .. "Elbow"]

			-- Avatar bodies don't all orient their joint frames (rig attachments)
			-- like the plain blocky rig. The reach aim has to be put into each
			-- arm part's own frame, or the upper and lower arm are aimed at two
			-- slightly different poses and fight each other through the elbow.
			-- Both offsets are "no change" on a plain rig.
			local shoulderJoint = rigState.joints[side .. "Shoulder"]
			local upperOffset, lowerOffset = CFrame.identity, CFrame.identity
			if shoulderJoint then
				upperOffset = LIMB_AXIS:Inverse() * shoulderJoint.a0.CFrame.Rotation
				if elbow then
					lowerOffset = upperOffset * shoulderJoint.a1.CFrame.Rotation:Inverse() * elbow.a0.CFrame.Rotation
				end
				local _, upperAngle = upperOffset:ToAxisAngle()
				local _, lowerAngle = lowerOffset:ToAxisAngle()
				print(string.format(
					"[HFF] %s arm frames: shoulder turned %.0f°, forearm turned %.0f° (0 on a plain rig)",
					side,
					math.deg(upperAngle),
					math.deg(lowerAngle)
				))
			end

			rigState.arms[side] = {
				side = side,
				elbowJoint = elbow,
				-- How the forearm's joint frame is turned relative to the upper arm's (none in a normal rig).
				elbowRest = if elbow
					then elbow.a0.CFrame.Rotation:Inverse() * elbow.a1.CFrame.Rotation
					else CFrame.identity,
				hand = hand,
				mass = mass,
				length = length,
				parts = armParts,
				light = false,
				drag = drag,
				shoulderPivot = if rigState.joints[side .. "Shoulder"] then rigState.joints[side .. "Shoulder"].a1 else nil,
				upperOffset = upperOffset,
				lowerOffset = lowerOffset,
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
		for _, arm in rigState.arms do
			arm.drag.Force = Vector3.zero
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
