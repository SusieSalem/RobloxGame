-- Grab
-- Hands grip whatever they touch while the arm is held. The server creates
-- the actual grip constraint so everyone sees it.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)

local Config = Shared.Config
local grabRemote = Shared.Remotes.Grab
local GRIP_NAME = Shared.GRIP_NAME
local closestPointOnPart = Util.closestPointOnPart

local Grab = {}

local surfaceParams = RaycastParams.new()
surfaceParams.FilterType = Enum.RaycastFilterType.Include

-- The point on the part's real surface nearest the hand. closestPointOnPart
-- only knows the bounding box, which for wedges, balls and meshes can be a
-- point in thin air, so those are checked with a ray at the actual shape.
local function surfacePoint(part: BasePart, from: Vector3): Vector3?
	local boxPoint = closestPointOnPart(part, from)
	if part:IsA("Part") and part.Shape == Enum.PartType.Block then
		return boxPoint
	end
	surfaceParams.FilterDescendantsInstances = { part }
	local offset = boxPoint - from
	if offset.Magnitude < 0.05 then
		-- The hand is inside the bounding box: aim at the middle of the part
		-- instead. No hit from there means the hand is inside the shape itself.
		local toCentre = part.Position - from
		if toCentre.Magnitude < 0.05 then
			return from
		end
		local hit = Workspace:Raycast(from, toCentre, surfaceParams)
		return if hit then hit.Position else from
	end
	local hit = Workspace:Raycast(from, offset.Unit * (offset.Magnitude + 1), surfaceParams)
	return if hit then hit.Position else nil
end

local function findGrabTarget(rigState, hand: BasePart): (BasePart?, Vector3?)
	local best: BasePart? = nil
	local bestPoint: Vector3? = nil
	local bestDistance = math.huge
	local core = rigState.core
	local halfHand = hand.Size / 2
	local searchRadius = halfHand.Magnitude + Config.GrabRadius
	for _, part in Workspace:GetPartBoundsInRadius(hand.Position, searchRadius, rigState.overlapParams) do
		if part:GetAttribute("HFFNoGrab") or (part.Parent and part.Parent:IsA("Accessory")) then
			continue
		end
		if not part.CanCollide then
			continue
		end
		-- Invisible walls would look like grabbing air (other players' limb
		-- colliders are invisible on purpose and stay grabbable).
		if part.Transparency >= 1 and part.Name ~= "HFFCollider" then
			continue
		end
		local point = surfacePoint(part, hand.Position)
		if not point then
			continue
		end
		-- Only things in front of the body can be grabbed.
		if (point - core.Position):Dot(core.CFrame.LookVector) < 0 then
			continue
		end
		-- Gap between the surface and the hand itself (not the hand's centre),
		-- so the hand has to really touch before it grips.
		local localPoint = hand.CFrame:PointToObjectSpace(point)
		local distance = Vector3.new(
			math.max(math.abs(localPoint.X) - halfHand.X, 0),
			math.max(math.abs(localPoint.Y) - halfHand.Y, 0),
			math.max(math.abs(localPoint.Z) - halfHand.Z, 0)
		).Magnitude
		if distance < bestDistance and distance <= Config.GrabRadius then
			best, bestPoint, bestDistance = part, point, distance
		end
	end
	return best, bestPoint
end

function Grab.update(rigState, arm, held: boolean, now: number)
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

function Grab.isGripping(arm): boolean
	return arm.hand:FindFirstChild(GRIP_NAME) ~= nil
end

return Grab
