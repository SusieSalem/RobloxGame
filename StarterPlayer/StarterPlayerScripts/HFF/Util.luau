-- Util
-- Small math helpers shared by the controller modules.

local Workspace = game:GetService("Workspace")

local Util = {}

function Util.closestPointOnPart(part: BasePart, point: Vector3): Vector3
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return part.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	))
end

function Util.yawFromDirection(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- Yaw of the camera, used for camera-relative movement and aiming.
function Util.getCameraYaw(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	return Util.yawFromDirection(camera.CFrame.LookVector)
end

-- Smooth random value in [-1, 1].
function Util.noise(t: number, seed: number): number
	return math.clamp(math.noise(t, seed, 0.5) * 2, -1, 1)
end

return Util
