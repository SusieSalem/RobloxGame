-- Theme
-- Colors, fonts and sizes for every HUD element, in one place.

local Theme = {}

Theme.Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Theme.FontRegular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

Theme.Colors = {
	Panel = Color3.fromRGB(16, 18, 24),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(245, 246, 250),
	TextMuted = Color3.fromRGB(165, 170, 186),
	Accent = Color3.fromRGB(255, 200, 61),
	Danger = Color3.fromRGB(255, 96, 96),
	Good = Color3.fromRGB(96, 214, 140),
	KeyCap = Color3.fromRGB(44, 48, 60),
	SwitchOff = Color3.fromRGB(70, 74, 88),
}

Theme.PanelTransparency = 0.18
Theme.StrokeTransparency = 0.88
Theme.Radius = UDim.new(0, 12)
Theme.Padding = 10
Theme.Gap = 6
Theme.TextSize = 18
Theme.SmallTextSize = 14

Theme.Tween = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return Theme
