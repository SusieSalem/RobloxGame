-- ControlHints
-- Compact list of controls in the bottom-left corner. It switches between
-- keyboard and gamepad glyphs, and hides on touch (the buttons are labeled).

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Strings = require(script.Parent.Strings)
local Components = require(script.Parent.Components)

local HFF = script.Parent.Parent:WaitForChild("HFF")
local Shared = require(HFF.Shared)
local Input = require(HFF.Input)

local Config = Shared.Config

local ControlHints = {}

local function rowsFor(mode: string)
	if mode == "Gamepad" then
		return {
			{ "LS", Strings.Move },
			{ "RS", Strings.Camera },
			{ "A", Strings.Jump },
			{ "LT", Strings.LeftArm },
			{ "RT", Strings.RightArm },
			{ Config.RagdollGamepadButton.Name:gsub("^Button", ""), Strings.Ragdoll },
		}
	end
	return {
		{ "WASD", Strings.Move },
		{ "Space", Strings.Jump },
		{ "LMB", Strings.LeftArm },
		{ "RMB", Strings.RightArm },
		{ Config.RagdollKey.Name, Strings.Ragdoll },
		{ "Alt", Strings.FreeMouse },
		{ Config.SettingsKey.Name, Strings.Settings },
		{ Config.HintsKey.Name, Strings.HideHints },
	}
end

function ControlHints.mount(parent: Instance)
	local create = Components.create
	local shown = Config.ShowControlHints

	local panel = Components.panel({
		Name = "ControlHints",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Parent = parent,
	}, {
		Components.padding(),
		Components.list(Enum.FillDirection.Vertical, 4),
	})

	local function rebuild()
		for _, child in panel:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, row in rowsFor(Input.getMode()) do
			create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(),
				LayoutOrder = index,
				Parent = panel,
			}, {
				Components.list(Enum.FillDirection.Horizontal, 8),
				Components.keyCap(row[1]),
				Components.label(row[2], {
					TextSize = Theme.SmallTextSize,
					FontFace = Theme.FontRegular,
					TextColor3 = Theme.Colors.TextMuted,
					LayoutOrder = 2,
				}),
			})
		end
		panel.Visible = shown and Input.getMode() ~= "Touch"
	end
	rebuild()

	Shared.InputModeChanged:Connect(rebuild)
	Shared.SettingChanged:Connect(function(name, value)
		if name == "ShowHints" then
			shown = value
			rebuild()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Config.HintsKey then
			shown = not shown
			rebuild()
			Shared.SettingChanged:Fire("ShowHintsToggled", shown)
		end
	end)
end

return ControlHints
