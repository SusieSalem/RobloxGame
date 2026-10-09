-- HFFPlayground
-- Builds a small test area for the movement: loose crates to carry, a wall
-- with a ledge to climb (and to fall off for knockdown tests), and a plank.
-- Turn it off with Config.SpawnPlayground = false.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("HFFMovementConfig"))

if not Config.SpawnPlayground or workspace:FindFirstChild("HFFPlayground") then
	return
end

local folder = Instance.new("Folder")
folder.Name = "HFFPlayground"

local function block(name: string, size: Vector3, cframe: CFrame, anchored: boolean, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = anchored
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local stone = Color3.fromRGB(150, 150, 160)
local wood = Color3.fromRGB(196, 140, 84)

-- Climb wall: 9 studs tall (falling off the top is enough to knock you down),
-- with a platform behind it.
block("ClimbWall", Vector3.new(16, 9, 2), CFrame.new(0, 4.5, -30), true, stone)
block("ClimbTop", Vector3.new(16, 1, 12), CFrame.new(0, 8.5, -37), true, stone)
block("Ledge", Vector3.new(16, 0.6, 1), CFrame.new(0, 8.7, -28.5), true, Color3.fromRGB(110, 110, 120))

-- Half-height step next to it for an easier climb.
block("Step", Vector3.new(6, 4.5, 4), CFrame.new(11, 2.25, -29), true, stone)

-- Loose crates.
for i = 0, 3 do
	block("Crate", Vector3.new(3, 3, 3), CFrame.new(-12 + i * 4, 1.5, -12), false, wood)
end
block("BigCrate", Vector3.new(5, 5, 5), CFrame.new(14, 2.5, -12), false, wood)

-- A plank to carry or use as a ramp.
block("Plank", Vector3.new(1, 0.6, 12), CFrame.new(-6, 0.3, -20), false, wood)

folder.Parent = workspace
