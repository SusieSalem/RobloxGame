-- UpdateLog
-- In-game list of updates, newest at the top (data in ChangeLog). Opens with
-- the button next to the gear or the U key. On join, a short toast shows the
-- latest update.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Strings = require(script.Parent.Strings)
local Components = require(script.Parent.Components)
local ChangeLog = require(script.Parent.ChangeLog)

local HFF = script.Parent.Parent:WaitForChild("HFF")
local Shared = require(HFF.Shared)

local Config = Shared.Config
local State = Shared.State

local OPEN_KEY = Enum.KeyCode.U
local TOAST_TIME = 6

local UpdateLog = {}

local function entryCard(entry, order: number)
	local create = Components.create
	local lines = {
		Components.list(Enum.FillDirection.Vertical, 4),
		Components.label(entry.title, {
			TextColor3 = if order == 1 then Theme.Colors.Accent else Theme.Colors.Text,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 1,
		}),
		Components.label(entry.date, {
			TextSize = Theme.SmallTextSize - 2,
			FontFace = Theme.FontRegular,
			TextColor3 = Theme.Colors.TextMuted,
			LayoutOrder = 2,
		}),
	}
	for index, change in entry.changes do
		table.insert(lines, Components.label("• " .. change, {
			TextSize = Theme.SmallTextSize,
			FontFace = Theme.FontRegular,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2 + index,
		}))
	end
	return create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = order,
	}, lines)
end

function UpdateLog.mount(parent: Instance)
	local create = Components.create
	local latest = ChangeLog[1]

	local button = create("TextButton", {
		Name = "UpdatesButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 10),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Accent,
		Text = Strings.Updates,
		FontFace = Theme.Font,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.Colors.Panel,
		AutoButtonColor = true,
		Parent = parent,
	}, {
		Components.corner(),
		Components.stroke(),
		create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})

	local list = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 380),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Accent,
		LayoutOrder = 2,
	}, { Components.list(Enum.FillDirection.Vertical, 14) })
	list:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Top
	for index, entry in ChangeLog do
		entryCard(entry, index).Parent = list
	end

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
		Name = "UpdateLog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(420, 0),
		Visible = false,
		Parent = parent,
	}, {
		Components.padding(16),
		Components.list(Enum.FillDirection.Vertical, 12),
		Components.label(Strings.Updates, { TextSize = 24, LayoutOrder = 1 }),
		list,
		closeButton,
	})
	local pop = create("UIScale", { Scale = 1, Parent = card })

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
			list.CanvasPosition = Vector2.zero
			pop.Scale = 0.9
			Components.tween(pop, { Scale = 1 })
		else
			State.mouseFree = not Config.CameraLockMouse
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card) then
				GuiService.SelectedObject = nil
			end
		end
	end

	button.Activated:Connect(function()
		setOpen(not open)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == OPEN_KEY then
			setOpen(not open)
		elseif open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			setOpen(false)
		end
	end)

	-- Toast with the latest update, shown for a few seconds after joining.
	if latest then
		local toast = Components.panel({
			Name = "LatestUpdate",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Parent = parent,
		}, {
			Components.padding(10),
			Components.label(string.format(Strings.LatestUpdate, latest.title), {
				TextSize = Theme.SmallTextSize,
			}),
		})
		local toastScale = create("UIScale", { Scale = 0.8, Parent = toast })
		Components.tween(toastScale, { Scale = 1 })
		task.delay(TOAST_TIME, function()
			toast:Destroy()
		end)
	end
end

return UpdateLog
