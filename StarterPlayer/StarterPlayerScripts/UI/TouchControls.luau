-- TouchControls
-- On-screen buttons for phones and tablets: hold L / R to raise each arm, tap
-- Ragdoll to lose balance. They sit around Roblox's jump button and scale with
-- the screen height so they stay thumb-sized.

local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Strings = require(script.Parent.Strings)
local Components = require(script.Parent.Components)
local Responsive = require(script.Parent.Responsive)

local HFF = script.Parent.Parent:WaitForChild("HFF")
local Shared = require(HFF.Shared)
local Input = require(HFF.Input)

local Config = Shared.Config

local TouchControls = {}

local function styleButton(button: GuiButton, round: boolean)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Colors.Panel
	button.BackgroundTransparency = 0.3
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	Components.corner(if round then UDim.new(1, 0) else UDim.new(0.5, 0)).Parent = button
	local stroke = Components.stroke()
	stroke.Thickness = Theme.StrokeThickness + 1
	stroke.Parent = button
	return stroke
end

local function setPressed(button: GuiButton, stroke: UIStroke, pressed: boolean)
	Components.tween(button, { BackgroundTransparency = if pressed then 0.05 else 0.3 })
	Components.tween(stroke, {
		Color = if pressed then Theme.Colors.Accent else Theme.Colors.Stroke,
		Transparency = if pressed then 0 else Theme.StrokeTransparency,
	})
end

-- Hold button that tracks every finger on it.
local function holdButton(parent: Instance, text: string, onHeld: (boolean) -> ())
	local button = Components.create("TextButton", {
		Text = text,
		FontFace = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Colors.Text,
		Parent = parent,
	}, {
		Components.create("UIPadding", {
			PaddingTop = UDim.new(0.22, 0),
			PaddingBottom = UDim.new(0.22, 0),
		}),
	})
	local stroke = styleButton(button, true)

	local fingers = 0
	local function refresh()
		onHeld(fingers > 0)
		setPressed(button, stroke, fingers > 0)
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		fingers += 1
		refresh()
		local connection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				connection:Disconnect()
				fingers = math.max(fingers - 1, 0)
				refresh()
			end
		end)
	end)
	return button
end

function TouchControls.mount(playerGui: Instance, onRagdoll: () -> ())
	local gui = Components.create("ScreenGui", {
		Name = "HFFTouch",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = Input.isTouch(),
		Parent = playerGui,
	})

	local left = holdButton(gui, "L", function(held)
		Input.setTouchArm("Left", held)
	end)
	local right = holdButton(gui, "R", function(held)
		Input.setTouchArm("Right", held)
	end)

	local ragdoll = Components.create("TextButton", {
		Text = Strings.Ragdoll,
		FontFace = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Colors.Text,
		Parent = gui,
	}, {
		Components.create("UIPadding", {
			PaddingTop = UDim.new(0.2, 0),
			PaddingBottom = UDim.new(0.2, 0),
			PaddingLeft = UDim.new(0.1, 0),
			PaddingRight = UDim.new(0.1, 0),
		}),
	})
	local ragdollStroke = styleButton(ragdoll, false)
	ragdoll.Activated:Connect(function()
		setPressed(ragdoll, ragdollStroke, true)
		onRagdoll()
		task.delay(0.15, setPressed, ragdoll, ragdollStroke, false)
	end)

	-- Button size follows the screen height; layout is around the jump button
	-- (bottom right): R above it, L to its left, Ragdoll above L.
	local function layout()
		local viewport = Responsive.viewport()
		local size = math.clamp(viewport.Y * Config.MobileButtonScale, 56, 110)
		left.Size = UDim2.fromOffset(size, size)
		left.Position = UDim2.new(1, -size * 2.55, 1, -size * 0.95)
		right.Size = UDim2.fromOffset(size, size)
		right.Position = UDim2.new(1, -size * 1.0, 1, -size * 2.45)
		ragdoll.Size = UDim2.fromOffset(size * 1.3, size * 0.5)
		ragdoll.Position = UDim2.new(1, -size * 2.55, 1, -size * 2.25)
	end
	layout()
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	Shared.InputModeChanged:Connect(function(mode)
		gui.Enabled = mode == "Touch"
	end)
end

return TouchControls
