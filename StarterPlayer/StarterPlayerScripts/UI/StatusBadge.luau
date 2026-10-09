-- StatusBadge
-- Pill at the top of the screen that says what the body is doing:
-- losing balance, ragdolled, knocked out, getting up. Hidden while normal.

local Theme = require(script.Parent.Theme)
local Strings = require(script.Parent.Strings)
local Components = require(script.Parent.Components)

local HFF = script.Parent.Parent:WaitForChild("HFF")
local Shared = require(HFF.Shared)
local Input = require(HFF.Input)

local Config = Shared.Config

local StatusBadge = {}

local function ragdollKeyLabel(): string
	local mode = Input.getMode()
	if mode == "Gamepad" then
		return (Config.RagdollGamepadButton.Name:gsub("^Button", ""))
	elseif mode == "Touch" then
		return Strings.Ragdoll
	end
	return Config.RagdollKey.Name
end

-- Returns (key, title, subtitle, color) for the current state, or nil to hide.
local function describe(rigState)
	if not rigState then
		return nil
	end
	local state = rigState.state
	if state == "Stagger" then
		if rigState.teeterManual then
			return "teeter", Strings.Teetering, Strings.TeeteringHint, Theme.Colors.Accent
		end
		return "stumble", Strings.Stumbling, "", Theme.Colors.Accent
	elseif state == "Knocked" then
		if rigState.manualRagdoll then
			return "ragdoll", Strings.Ragdolled, Strings.RagdolledHint:format(ragdollKeyLabel()), Theme.Colors.Accent
		end
		return "knocked", Strings.KnockedOut, "", Theme.Colors.Danger
	elseif state == "Recovering" then
		return "recovering", Strings.GettingUp, "", Theme.Colors.Good
	end
	return nil
end

-- Builds the badge under parent; returns an update(rigState) function to call every frame.
function StatusBadge.mount(parent: Instance)
	local create = Components.create

	local dot = create("Frame", {
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.Colors.Accent,
		LayoutOrder = 1,
	}, { Components.corner(UDim.new(1, 0)) })
	local title = Components.label("", { TextSize = 22, LayoutOrder = 2 })
	local header = create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		LayoutOrder = 1,
	}, { Components.list(Enum.FillDirection.Horizontal, 8), dot, title })
	local subtitle = Components.label("", {
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.Colors.TextMuted,
		FontFace = Theme.FontRegular,
		LayoutOrder = 2,
	})
	local pop = create("UIScale", { Scale = 1 })

	local badge = Components.panel({
		Name = "StatusBadge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Visible = false,
		Parent = parent,
	}, {
		Components.padding(),
		create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
		Components.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center),
		header,
		subtitle,
		pop,
	})
	-- Two UIPaddings are not allowed; keep the wider horizontal one.
	for _, child in badge:GetChildren() do
		if child:IsA("UIPadding") and child.PaddingLeft.Offset ~= 18 then
			child:Destroy()
		end
	end
	badge:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, Theme.Padding)
	badge:FindFirstChildOfClass("UIPadding").PaddingBottom = UDim.new(0, Theme.Padding)

	local currentKey = nil
	local currentSubtitle = nil
	return function(rigState)
		local key, titleText, subtitleText, color = describe(rigState)
		if key == currentKey and subtitleText == currentSubtitle then
			return
		end
		currentKey, currentSubtitle = key, subtitleText
		if not key then
			badge.Visible = false
			return
		end
		title.Text = titleText
		subtitle.Text = subtitleText
		subtitle.Visible = subtitleText ~= ""
		dot.BackgroundColor3 = color
		if not badge.Visible then
			badge.Visible = true
			pop.Scale = 0.85
			Components.tween(pop, { Scale = 1 })
		end
	end
end

return StatusBadge
