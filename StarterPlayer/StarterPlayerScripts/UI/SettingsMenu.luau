-- SettingsMenu
-- Gear button (top right) and a small settings card. Opens with the gear,
-- the settings key (M) or the gamepad Select button. Frees the mouse while
-- open so you can click.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Strings = require(script.Parent.Strings)
local Components = require(script.Parent.Components)

local HFF = script.Parent.Parent:WaitForChild("HFF")
local Shared = require(HFF.Shared)
local Input = require(HFF.Input)

local Config = Shared.Config
local State = Shared.State

local SettingsMenu = {}

function SettingsMenu.mount(parent: Instance)
	local create = Components.create

	local gear = create("ImageButton", {
		Name = "SettingsButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		Image = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png",
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = true,
		Parent = parent,
	}, {
		Components.corner(),
		Components.stroke(),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})

	local rows = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, { Components.list(Enum.FillDirection.Vertical, 4) })

	local closeButton = create("TextButton", {
		Text = Strings.Close,
		FontFace = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Theme.Colors.Panel,
		BackgroundColor3 = Theme.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
	}, { Components.corner(UDim.new(0, 12)), Components.stroke() })

	local card = Components.panel({
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(340, 0),
		Visible = false,
		Parent = parent,
	}, {
		Components.padding(16),
		Components.list(Enum.FillDirection.Vertical, 12),
		Components.label(Strings.Settings, { TextSize = 24, LayoutOrder = 1 }),
		rows,
		closeButton,
	})
	local pop = create("UIScale", { Scale = 1, Parent = card })

	local hintsShown = Config.ShowControlHints
	local firstRow = nil
	local function addSwitch(order: number, text: string, initial: boolean, onChanged: (boolean) -> ())
		local row, set = Components.switchRow(text, initial, onChanged)
		row.LayoutOrder = order
		row.Parent = rows
		firstRow = firstRow or row
		return set
	end

	addSwitch(1, Strings.SettingMouseLock, Config.CameraLockMouse, function(value)
		Config.CameraLockMouse = value
	end)
	addSwitch(2, Strings.SettingEuphoria, Config.EuphoriaEnabled, function(value)
		Config.EuphoriaEnabled = value
	end)
	addSwitch(3, Strings.SettingLegIK, Config.LegIK, function(value)
		Config.LegIK = value
	end)
	local setHints = addSwitch(4, Strings.SettingHints, hintsShown, function(value)
		hintsShown = value
		Shared.SettingChanged:Fire("ShowHints", value)
	end)
	Shared.SettingChanged:Connect(function(name, value)
		if name == "ShowHintsToggled" then
			hintsShown = value
			setHints(value)
		end
	end)

	local open = false
	local function setOpen(value: boolean)
		if value == open then
			return
		end
		open = value
		card.Visible = open
		if open then
			State.mouseFree = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			pop.Scale = 0.9
			Components.tween(pop, { Scale = 1 })
			if Input.getMode() == "Gamepad" then
				GuiService.SelectedObject = firstRow
			end
		else
			State.mouseFree = not Config.CameraLockMouse
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card) then
				GuiService.SelectedObject = nil
			end
		end
	end

	gear.Activated:Connect(function()
		setOpen(not open)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed and input.KeyCode ~= Enum.KeyCode.ButtonSelect then
			return
		end
		if input.KeyCode == Config.SettingsKey or input.KeyCode == Enum.KeyCode.ButtonSelect then
			setOpen(not open)
		elseif open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			setOpen(false)
		end
	end)
end

return SettingsMenu
