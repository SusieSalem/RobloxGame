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
	-- Looking almost straight up or down, the flat part of the look direction
	-- is tiny and jumps around, which used to make the body shake. The camera's
	-- up vector then points along the same horizontal direction (backward when
	-- looking up, forward when looking down), so add it in to keep the yaw steady.
	local cframe = camera.CFrame
	local look, up = cframe.LookVector, cframe.UpVector
	local flat = Vector3.new(look.X, 0, look.Z) - Vector3.new(up.X, 0, up.Z) * math.sign(look.Y)
	if flat.Magnitude < 1e-4 then
		flat = Vector3.new(look.X, 0, look.Z)
	end
	return Util.yawFromDirection(flat)
end

-- Smooth random value in [-1, 1].
function Util.noise(t: number, seed: number): number
	return math.clamp(math.noise(t, seed, 0.5) * 2, -1, 1)
end

return Util
