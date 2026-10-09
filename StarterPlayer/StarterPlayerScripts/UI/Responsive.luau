-- Responsive
-- Scales the HUD with the screen so it reads the same on a phone, a laptop
-- and a TV. 720p is the design size.

local Workspace = game:GetService("Workspace")

local Responsive = {}

local DESIGN_HEIGHT = 720
local MIN_SCALE, MAX_SCALE = 0.75, 1.4

function Responsive.viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- Small screens (phones) get compact layouts.
function Responsive.isCompact(): boolean
	return Responsive.viewport().Y < 500
end

-- Adds a UIScale to the gui and keeps it updated.
function Responsive.attach(gui: LayerCollector)
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local function update()
		local viewport = Responsive.viewport()
		scale.Scale = math.clamp(viewport.Y / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE)
	end

	local connection
	local function watchCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	return scale
end

return Responsive
