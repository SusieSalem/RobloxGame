-- Components
-- Small building blocks for the HUD: panels, labels, key caps, buttons and
-- switches, all styled from Theme.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Components = {}

-- create("Frame", { Size = ... }, { child1, child2 })
function Components.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end
local create = Components.create

function Components.corner(radius: UDim?)
	return create("UICorner", { CornerRadius = radius or Theme.Radius })
end

function Components.stroke()
	return create("UIStroke", {
		Color = Theme.Colors.Stroke,
		Transparency = Theme.StrokeTransparency,
		Thickness = Theme.StrokeThickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Black outline around the text itself (not the box).
function Components.textStroke(thickness: number?)
	return create("UIStroke", {
		Color = Theme.Colors.Stroke,
		Thickness = thickness or Theme.TextStrokeThickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Components.padding(amount: number?)
	local padding = UDim.new(0, amount or Theme.Padding)
	return create("UIPadding", {
		PaddingTop = padding,
		PaddingBottom = padding,
		PaddingLeft = padding,
		PaddingRight = padding,
	})
end

function Components.list(direction: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?)
	return create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.Gap),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Rounded translucent card that sizes itself to its content.
function Components.panel(props: { [string]: any }?, children: { Instance }?)
	local frame = create("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}, children)
	Components.corner().Parent = frame
	Components.stroke().Parent = frame
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function Components.label(text: string, props: { [string]: any }?)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Theme.Colors.Text,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { Components.textStroke() })
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

-- A key / button glyph like [R] or [LMB].
function Components.keyCap(text: string)
	local cap = create("TextLabel", {
		BackgroundColor3 = Theme.Colors.KeyCap,
		Text = text,
		FontFace = Theme.Font,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.Colors.KeyCapText,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(28, 28),
	}, {
		Components.corner(UDim.new(0, 8)),
		create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
		create("UISizeConstraint", { MinSize = Vector2.new(28, 28) }),
	})
	local border = Components.stroke()
	border.Thickness = 2
	border.Parent = cap
	return cap
end

function Components.tween(instance: Instance, goal: { [string]: any }, info: TweenInfo?)
	local tween = TweenService:Create(instance, info or Theme.Tween, goal)
	tween:Play()
	return tween
end

-- On/off switch row. Returns the row and a setter.
function Components.switchRow(text: string, initial: boolean, onChanged: (boolean) -> ())
	local value = initial

	local knob = create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Colors.Text,
	}, { Components.corner(UDim.new(1, 0)) })
	local knobStroke = Components.stroke()
	knobStroke.Thickness = 2
	knobStroke.Parent = knob

	local track = create("Frame", {
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = Theme.Colors.SwitchOff,
		LayoutOrder = 2,
	}, { Components.corner(UDim.new(1, 0)), knob })
	local trackStroke = Components.stroke()
	trackStroke.Thickness = 2
	trackStroke.Parent = track

	local row = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Selectable = true,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		track,
		Components.label(text, { LayoutOrder = 1, Size = UDim2.new(1, -54, 1, 0), AutomaticSize = Enum.AutomaticSize.None, FontFace = Theme.FontRegular }),
	})

	local function render(animate: boolean)
		local trackGoal = { BackgroundColor3 = if value then Theme.Colors.Accent else Theme.Colors.SwitchOff }
		local knobGoal = { Position = if value then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) }
		if animate then
			Components.tween(track, trackGoal)
			Components.tween(knob, knobGoal)
		else
			track.BackgroundColor3 = trackGoal.BackgroundColor3
			knob.Position = knobGoal.Position
		end
	end
	render(false)

	row.Activated:Connect(function()
		value = not value
		render(true)
		onChanged(value)
	end)

	return row, function(newValue: boolean)
		value = newValue
		render(true)
	end
end

return Components
