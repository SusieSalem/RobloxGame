-- HFFServer
-- Turns every R15 character into a physics ragdoll (ball sockets instead of
-- Motor6Ds), gives the owning client network ownership so its movement is
-- responsive, and handles grabbing so grips replicate to everyone.
--
-- Other server scripts can knock a player down with:
--   ReplicatedStorage.HFFRemotes.ServerKnockdown:Fire(player, durationSeconds)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("HFFMovementConfig"))

-- The first draft (HFFCharacterSetup + an HFFConfig module) fights this script.
for _, old in { game:GetService("ServerScriptService"):FindFirstChild("HFFCharacterSetup", true) } do
	warn("[HFF] Old script still in the game, delete it: " .. old:GetFullName())
end

local GRIP_NAME = "HFFGrip"
local SIDES = { Left = true, Right = true }

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------

local remotes = ReplicatedStorage:FindFirstChild("HFFRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "HFFRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(className: string, name: string)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local grabRemote = getRemote("RemoteEvent", "Grab") :: RemoteEvent
local knockdownRemote = getRemote("RemoteEvent", "Knockdown") :: RemoteEvent
local serverKnockdown = getRemote("BindableEvent", "ServerKnockdown") :: BindableEvent

---------------------------------------------------------------------------
-- Ragdoll setup
---------------------------------------------------------------------------

-- Ball socket limits use the attachment's X axis as the cone axis, so rotate
-- the joint frames to point X along the limb: down for arms/legs, up for the head.
local LIMB_AXIS = CFrame.Angles(0, 0, -math.pi / 2)
local NECK_AXIS = CFrame.Angles(0, 0, math.pi / 2)

-- Extra pairs that sit close together but are not directly jointed.
local EXTRA_NO_COLLIDE = {
	{ "UpperTorso", "LeftUpperLeg" },
	{ "UpperTorso", "RightUpperLeg" },
	{ "LeftUpperLeg", "RightUpperLeg" },
	{ "LeftLowerLeg", "RightLowerLeg" },
	{ "LeftFoot", "RightFoot" },
	{ "LowerTorso", "LeftUpperArm" },
	{ "LowerTorso", "RightUpperArm" },
	{ "Head", "LeftUpperArm" },
	{ "Head", "RightUpperArm" },
}

local COLLIDER_NAME = "HFFCollider"

-- Parts whose collisions the Humanoid leaves alone; every other body part is a
-- limb and gets a collider.
local CORE_PARTS = { HumanoidRootPart = true, Head = true, UpperTorso = true, LowerTorso = true }

-- A body part plus its collider, if it has one.
local function collisionParts(part: BasePart): { BasePart }
	local list = { part }
	local collider = part:FindFirstChild(COLLIDER_NAME)
	if collider then
		table.insert(list, collider)
	end
	return list
end

local function noCollide(a: BasePart, b: BasePart)
	for _, partA in collisionParts(a) do
		for _, partB in collisionParts(b) do
			local constraint = Instance.new("NoCollisionConstraint")
			constraint.Name = "HFFNoCollide"
			constraint.Part0 = partA
			constraint.Part1 = partB
			constraint.Parent = a
		end
	end
end

-- The Humanoid keeps forcing CanCollide off on R15 arms and legs, which makes
-- them sink through the floor. An invisible welded collider inside each limb
-- does the colliding instead.
local function addLimbCollider(limb: BasePart, properties: PhysicalProperties)
	local collider = Instance.new("Part")
	collider.Name = COLLIDER_NAME
	collider.Size = limb.Size * Config.LimbColliderScale
	collider.CFrame = limb.CFrame
	collider.Transparency = 1
	collider.CanCollide = true
	collider.CanTouch = false
	collider.CanQuery = true -- other players can grab it
	collider.Massless = true
	collider.CustomPhysicalProperties = properties
	collider.Parent = limb

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = collider
	weld.Parent = collider

	limb.CanCollide = false
end

local function ragdollJoint(motor: Motor6D)
	local part0 = motor.Part0 :: BasePart
	local part1 = motor.Part1 :: BasePart
	local axis = if motor.Name == "Neck" then NECK_AXIS else LIMB_AXIS
	local limits = Config.JointLimits[motor.Name] or Config.DefaultJointLimit

	local a0 = Instance.new("Attachment")
	a0.Name = "HFFA0_" .. motor.Name
	a0.CFrame = motor.C0 * axis
	a0.Parent = part0

	local a1 = Instance.new("Attachment")
	a1.Name = "HFFA1_" .. motor.Name
	a1.CFrame = motor.C1 * axis
	a1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "HFFSocket_" .. motor.Name
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.LimitsEnabled = true
	socket.TwistLimitsEnabled = true
	socket.UpperAngle = limits.UpperAngle
	socket.TwistLowerAngle = limits.TwistLower
	socket.TwistUpperAngle = limits.TwistUpper
	socket.MaxFrictionTorque = Config.JointFrictionTorque
	socket.Parent = part1

	noCollide(part0, part1)
	-- Destroy (not just disable) so nothing can turn the rigid joint back on.
	motor:Destroy()
end

local function isLegPart(part: BasePart): boolean
	return part.Name:find("Leg") ~= nil or part.Name:find("Foot") ~= nil
end

local function applyPhysicalProperties(character: Model)
	local body = PhysicalProperties.new(Config.BodyDensity, Config.BodyFriction, Config.BodyElasticity, 1, 1)
	local legs = PhysicalProperties.new(Config.BodyDensity, Config.LegFriction, Config.BodyElasticity, 1, 1)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local properties = if isLegPart(part) then legs else body
			part.CustomPhysicalProperties = properties
			if CORE_PARTS[part.Name] then
				part.CanCollide = true
			elseif not part:FindFirstChild(COLLIDER_NAME) then
				addLimbCollider(part, properties)
			end
		end
	end
end

local function giveOwnership(player: Player, character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			pcall(part.SetNetworkOwner, part, player)
		end
	end
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("[HFF] " .. player.Name .. " is not R15; set Avatar type to R15 in Game Settings")
		return
	end

	-- Avatar scaling and packages rebuild joints, so wait for the appearance first.
	local deadline = os.clock() + 5
	while not player:HasAppearanceLoaded() and os.clock() < deadline do
		task.wait(0.1)
	end
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	if player.Character ~= character or character:GetAttribute("HFFReady") then
		return
	end

	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = false

	-- Default animations drive the Motor6Ds we keep (Root/Waist) and would fight physics.
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	root.CanCollide = false
	root.Massless = true

	applyPhysicalProperties(character)

	local ragdolled = 0
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 and not Config.RigidJoints[motor.Name] then
			ragdollJoint(motor)
			ragdolled += 1
		end
	end
	if ragdolled == 0 then
		warn("[HFF] No joints were converted for " .. player.Name .. "; is the avatar R15?")
	end
	for _, pair in EXTRA_NO_COLLIDE do
		local a = character:FindFirstChild(pair[1])
		local b = character:FindFirstChild(pair[2])
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			noCollide(a, b)
		end
	end

	giveOwnership(player, character)
	character:SetAttribute("HFFReady", true)
	print(string.format("[HFF] Ragdoll ready for %s (%d joints)", player.Name, ragdolled))
end

---------------------------------------------------------------------------
-- Grabbing
---------------------------------------------------------------------------

type Grip = {
	constraint: BallSocketConstraint,
	handAttachment: Attachment,
	targetAttachment: Attachment,
	target: BasePart,
	ownedRoot: BasePart?, -- loose prop whose ownership we handed to the grabber
}

local grips: { [Player]: { [string]: Grip } } = {}

local function closestPointOnPart(part: BasePart, point: Vector3): Vector3
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return part.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	))
end

local function isGripped(root: BasePart): boolean
	for _, sides in grips do
		for _, grip in sides do
			if grip.ownedRoot == root then
				return true
			end
		end
	end
	return false
end

local function release(player: Player, side: string)
	local sides = grips[player]
	local grip = sides and sides[side]
	if not grip then
		return
	end
	sides[side] = nil
	grip.constraint:Destroy()
	grip.handAttachment:Destroy()
	grip.targetAttachment:Destroy()

	local root = grip.ownedRoot
	if root and root.Parent and not isGripped(root) then
		pcall(root.SetNetworkOwnershipAuto, root)
	end
end

local function releaseAll(player: Player)
	for side in SIDES do
		release(player, side)
	end
end

local function grab(player: Player, side: string, target: BasePart, point: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not character:GetAttribute("HFFReady") then
		return
	end
	local hand = character:FindFirstChild(side .. "Hand")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	if target:IsDescendantOf(character) or not target:IsDescendantOf(workspace) or target:GetAttribute("HFFNoGrab") then
		return
	end
	if (hand.Position - point).Magnitude > Config.GrabRadius + Config.ServerGrabTolerance then
		return
	end
	if (closestPointOnPart(target, point) - point).Magnitude > Config.ServerGrabTolerance then
		return
	end

	release(player, side)

	local handAttachment = Instance.new("Attachment")
	handAttachment.Name = "HFFGripHand"
	handAttachment.Position = hand.CFrame:PointToObjectSpace(point)
	handAttachment.Parent = hand

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "HFFGripTarget"
	targetAttachment.Position = target.CFrame:PointToObjectSpace(point)
	targetAttachment.Parent = target

	local constraint = Instance.new("BallSocketConstraint")
	constraint.Name = GRIP_NAME
	constraint.Attachment0 = handAttachment
	constraint.Attachment1 = targetAttachment
	constraint.Parent = hand -- the client looks for this to know the hand is gripping

	-- Loose props (not anchored, not someone's body) move with the grabber's
	-- physics so carrying them has no lag.
	local ownedRoot: BasePart? = nil
	local targetRoot = target.AssemblyRootPart
	local targetModel = target:FindFirstAncestorOfClass("Model")
	local isCharacter = targetModel ~= nil and Players:GetPlayerFromCharacter(targetModel) ~= nil
	if targetRoot and not isCharacter and not targetRoot.Anchored then
		if pcall(targetRoot.SetNetworkOwner, targetRoot, player) then
			ownedRoot = targetRoot
		end
	end

	grips[player] = grips[player] or {}
	grips[player][side] = {
		constraint = constraint,
		handAttachment = handAttachment,
		targetAttachment = targetAttachment,
		target = target,
		ownedRoot = ownedRoot,
	}
end

grabRemote.OnServerEvent:Connect(function(player: Player, action: any, side: any, target: any, point: any)
	if typeof(side) ~= "string" or not SIDES[side] then
		return
	end
	if action == "Release" then
		release(player, side)
	elseif action == "Grab" then
		if typeof(target) == "Instance" and target:IsA("BasePart") and typeof(point) == "Vector3" then
			grab(player, side, target, point)
		end
	end
end)

-- Drop grips that were stretched too far or whose target vanished.
RunService.Heartbeat:Connect(function()
	for player, sides in grips do
		for side, grip in sides do
			local broken = not grip.constraint.Parent
				or not grip.target:IsDescendantOf(workspace)
				or not grip.handAttachment.Parent
				or (grip.handAttachment.WorldPosition - grip.targetAttachment.WorldPosition).Magnitude
					> Config.GripBreakDistance
			if broken then
				release(player, side)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Knockdown from other server scripts
---------------------------------------------------------------------------

serverKnockdown.Event:Connect(function(player: Player, duration: number?)
	knockdownRemote:FireClient(player, duration)
end)

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------

local function onPlayer(player: Player)
	local function onCharacter(character: Model)
		releaseAll(player)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				releaseAll(player)
			end)
		end
		setupCharacter(player, character)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

print("[HFF] Server running")

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	releaseAll(player)
	grips[player] = nil
end)
