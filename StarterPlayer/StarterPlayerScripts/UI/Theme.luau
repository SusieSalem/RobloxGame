-- Theme
-- Colors, fonts and sizes for every HUD element, in one place.
-- Cartoon look: chunky rounded font, bright solid colors, thick black outlines
-- and bouncy animations.

local Theme = {}

Theme.Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
Theme.FontRegular = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

Theme.Colors = {
	Panel = Color3.fromRGB(58, 66, 150),
	Stroke = Color3.fromRGB(18, 14, 28), -- the black cartoon outline
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(214, 220, 255),
	Accent = Color3.fromRGB(255, 213, 0),
	Danger = Color3.fromRGB(255, 82, 82),
	Good = Color3.fromRGB(72, 220, 120),
	KeyCap = Color3.fromRGB(255, 255, 255),
	KeyCapText = Color3.fromRGB(18, 14, 28),
	SwitchOff = Color3.fromRGB(120, 126, 170),
}

Theme.PanelTransparency = 0.05
Theme.StrokeTransparency = 0
Theme.StrokeThickness = 3 -- outline around panels and buttons
Theme.TextStrokeThickness = 2 -- outline around text
Theme.Radius = UDim.new(0, 18)
Theme.Padding = 12
Theme.Gap = 6
Theme.TextSize = 20
Theme.SmallTextSize = 16

Theme.Tween = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

return Theme
