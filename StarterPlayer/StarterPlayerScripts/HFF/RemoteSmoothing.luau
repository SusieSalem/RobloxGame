-- RemoteSmoothing
-- Makes other players' ragdolls look smooth on this client.
--
-- Each player simulates their own body, and the engine replicates every loose
-- limb as its own assembly at a low, uneven rate. Seen from another client the
-- limbs arrive out of step with the torso, so the body jitters and the joints
-- pull apart.
--
-- For every other player this module hides the replicated body and shows a
-- local, anchored copy instead. Each frame the copy's torso eases toward the
-- replicated torso, and every limb is rebuilt from its joint (only the joint's
-- rotation is taken from the replicated parts), so limbs always stay attached.
--
-- The replicated body keeps doing all the physics: collisions and grabbing are
-- unchanged, and the local player's own character is never touched.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)

local Config = Shared.Config
local localPlayer = Shared.Player

local FOLDER_NAME = "HFFSmoothCharacters"
local ID_ATTRIBUTE = "HFFSmoothId"
local COLLIDER_NAME = "HFFCollider"
local OUTLINE_NAME = "HFFOutline"
local SYNC_INTERVAL = 0.5 -- how often we look for characters to copy or drop
local REBUILD_DELAY = 0.3 -- wait this long after the last appearance change

local RemoteSmoothing = {}

local entries = {} -- [Player] = visual copy state
local folder: Folder? = nil

-- Things that change how the body looks, so the copy has to be remade.
local function affectsLook(instance: Instance): boolean
	return instance:IsA("BasePart")
		or instance:IsA("Decal")
		or instance:IsA("Clothing")
		or instance:IsA("ShirtGraphic")
end

-- The body part an accessory handle (or any other extra part) is welded to.
local function findAnchor(real: BasePart, indexByReal): BasePart?
	for _, recursive in { false, true } do
		for _, connected in real:GetConnectedParts(recursive) do
			if indexByReal[connected] then
				return connected
			end
		end
	end
	return nil
end

local function destroyEntry(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	entries[player] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.clone:Destroy()
	for _, instance in entry.hidden do
		instance.LocalTransparencyModifier = 0
	end
	if entry.outline then
		entry.outline.Enabled = true
	end
	if entry.humanoid then
		entry.humanoid.DisplayDistanceType = entry.displayDistanceType
	end
end

local function buildEntry(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end

	-- Number every part so each copied part can be matched to its original.
	local realById = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(realById, descendant)
			descendant:SetAttribute(ID_ATTRIBUTE, #realById)
		end
	end
	local wasArchivable = character.Archivable
	character.Archivable = true -- characters can't be cloned otherwise
	local clone = character:Clone()
	character.Archivable = wasArchivable
	for _, part in realById do
		part:SetAttribute(ID_ATTRIBUTE, nil)
	end
	if not clone then
		return nil
	end
	clone:SetAttribute("HFFReady", nil)

	-- The copy keeps its Humanoid (clothing and the name tag need one) but it
	-- must never simulate or collide.
	local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
	if cloneHumanoid then
		cloneHumanoid.RequiresNeck = false
		cloneHumanoid.BreakJointsOnDeath = false
		cloneHumanoid.EvaluateStateMachine = false
		cloneHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	local visualByReal = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			local real = realById[descendant:GetAttribute(ID_ATTRIBUTE)]
			if descendant.Name == COLLIDER_NAME or not real then
				descendant:Destroy()
			else
				descendant:SetAttribute(ID_ATTRIBUTE, nil)
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false -- hands and ground probes only see the real body
				visualByReal[real] = descendant
			end
		elseif
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Constraint")
			or descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("NoCollisionConstraint")
			or descendant:IsA("ForceField")
		then
			descendant:Destroy()
		end
	end

	-- Joints the server built: child part -> how it hangs off its parent part.
	local links = {}
	for _, descendant in character:GetDescendants() do
		local rigid = descendant:IsA("RigidConstraint") and descendant.Name:sub(1, 9) == "HFFRigid_"
		local socket = descendant:IsA("BallSocketConstraint") and descendant.Name:sub(1, 10) == "HFFSocket_"
		if rigid or socket then
			local a0, a1 = descendant.Attachment0, descendant.Attachment1
			local part0, part1 = a0 and a0.Parent, a1 and a1.Parent
			if part0 and part1 and visualByReal[part0] and visualByReal[part1] then
				links[part1] = {
					parent = part0,
					c0 = a0.CFrame,
					c1 = a1.CFrame,
					c1Inverse = a1.CFrame:Inverse(),
					rigid = rigid,
				}
			end
		end
	end

	-- Body parts in parent-before-child order. Parts with no joint to a parent
	-- (normally just the HumanoidRootPart) follow the replicated part directly.
	local nodes = {}
	local indexByReal = {}
	local function addNode(real: BasePart, link)
		local node = { real = real, visual = visualByReal[real], cf = real.CFrame }
		if link then
			node.parent = indexByReal[link.parent]
			node.rigid = link.rigid
			node.c0 = link.c0
			node.c1 = link.c1
			node.c1Inverse = link.c1Inverse
			node.rel = (link.parent.CFrame * link.c0):ToObjectSpace(real.CFrame * link.c1).Rotation
		end
		table.insert(nodes, node)
		indexByReal[real] = #nodes
	end

	local pending = {}
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and visualByReal[child] then
			if links[child] then
				table.insert(pending, child)
			else
				addNode(child, nil)
			end
		end
	end
	while #pending > 0 do
		local progressed = false
		for i = #pending, 1, -1 do
			local real = pending[i]
			if indexByReal[links[real].parent] then
				addNode(real, links[real])
				table.remove(pending, i)
				progressed = true
			end
		end
		if not progressed then
			for _, real in pending do
				addNode(real, nil)
			end
			break
		end
	end

	-- Everything else (accessory handles) rides rigidly on a body part.
	local extras = {}
	local parts = {}
	for _, node in nodes do
		table.insert(parts, node.visual)
	end
	for real, visual in visualByReal do
		if not indexByReal[real] then
			local anchor = findAnchor(real, indexByReal)
			if anchor then
				table.insert(extras, {
					anchor = indexByReal[anchor],
					offset = anchor.CFrame:ToObjectSpace(real.CFrame),
				})
				table.insert(parts, visual)
			else
				visual:Destroy()
			end
		end
	end

	-- Hide the replicated body on this client only; it still collides.
	local hidden = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = 1
			table.insert(hidden, descendant)
		end
	end
	local outline = character:FindFirstChild(OUTLINE_NAME)
	if outline and outline:IsA("Highlight") and outline.Enabled then
		outline.Enabled = false -- the copy carries its own outline
	else
		outline = nil
	end
	local displayDistanceType = humanoid.DisplayDistanceType
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- the copy shows the name

	local entry = {
		character = character,
		humanoid = humanoid,
		root = root,
		clone = clone,
		nodes = nodes,
		extras = extras,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		hidden = hidden,
		outline = outline,
		displayDistanceType = displayDistanceType,
		connections = {},
		dirtyAt = nil :: number?,
	}

	local function markDirty(descendant: Instance)
		if affectsLook(descendant) then
			entry.dirtyAt = os.clock()
		end
	end
	table.insert(entry.connections, character.DescendantAdded:Connect(markDirty))
	table.insert(entry.connections, character.DescendantRemoving:Connect(markDirty))

	clone.Parent = folder
	return entry
end

local function stepEntry(entry, alpha: number, jointAlpha: number, lead: number)
	local nodes = entry.nodes
	local cframes = entry.cframes
	local snapDistance = Config.RemoteSmoothingSnapDistance

	for i, node in nodes do
		local real = node.real
		local cf
		if node.parent then
			local parent = nodes[node.parent]
			if node.rigid then
				cf = parent.cf * node.c0 * node.c1Inverse
			else
				-- Only the joint's rotation comes from the network, so the limb can
				-- never drift away from the part it hangs off.
				local target = (parent.real.CFrame * node.c0):ToObjectSpace(real.CFrame * node.c1).Rotation
				node.rel = node.rel:Lerp(target, jointAlpha)
				cf = parent.cf * node.c0 * node.rel * node.c1Inverse
			end
		else
			local realCFrame = real.CFrame
			if (realCFrame.Position - node.cf.Position).Magnitude > snapDistance then
				cf = realCFrame -- respawned or teleported: snap
			else
				-- Aim a little ahead along the velocity so easing doesn't trail behind.
				cf = node.cf:Lerp(realCFrame + real.AssemblyLinearVelocity * lead, alpha)
			end
		end
		node.cf = cf
		cframes[i] = cf
		if node.visual.CanCollide then
			node.visual.CanCollide = false -- in case the copy's Humanoid turns it back on
		end
	end

	local offset = #nodes
	for j, extra in entry.extras do
		cframes[offset + j] = nodes[extra.anchor].cf * extra.offset
	end

	Workspace:BulkMoveTo(entry.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Creates copies for characters that are ready and drops the ones that left,
-- respawned or changed appearance.
local function sync()
	local now = os.clock()
	for player, entry in entries do
		local stale = not Config.RemoteSmoothing
			or player.Parent ~= Players
			or player.Character ~= entry.character
			or (entry.dirtyAt ~= nil and now - entry.dirtyAt > REBUILD_DELAY)
		if stale then
			destroyEntry(player)
		end
	end
	if not Config.RemoteSmoothing then
		return
	end
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and not entries[player] then
			local character = player.Character
			if character and character:IsDescendantOf(Workspace) and character:GetAttribute("HFFReady") then
				entries[player] = buildEntry(player, character)
			end
		end
	end
end

function RemoteSmoothing.start()
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	local sinceSync = SYNC_INTERVAL
	RunService:BindToRenderStep("HFFRemoteSmoothing", Enum.RenderPriority.Character.Value, function(dt)
		sinceSync += dt
		if sinceSync >= SYNC_INTERVAL then
			sinceSync = 0
			sync()
		end

		local sharpness = math.max(Config.RemoteSmoothingSharpness, 1)
		local alpha = 1 - math.exp(-sharpness * dt)
		local jointAlpha = 1 - math.exp(-math.max(Config.RemoteSmoothingJointSharpness, 1) * dt)
		local lead = Config.RemoteSmoothingVelocityLead / sharpness

		for player, entry in entries do
			if entry.character.Parent and entry.root.Parent then
				stepEntry(entry, alpha, jointAlpha, lead)
			else
				destroyEntry(player) -- despawned or streamed out
			end
		end
	end)
end

return RemoteSmoothing
