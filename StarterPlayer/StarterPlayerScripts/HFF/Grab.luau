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
