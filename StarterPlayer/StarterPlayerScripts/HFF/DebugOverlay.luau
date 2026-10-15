-- DebugOverlay
-- A small on-screen readout for hunting physics bugs. The controller hands it
-- a few lines of numbers; a screenshot of it shows which system is misbehaving.
-- Turn it off with Config.DebugOverlay = false.

local Shared = require(script.Parent.Shared)

local player = Shared.Player

local DebugOverlay = {}

local label: TextLabel? = nil

-- Shows the text, or hides the readout when text is nil.
function DebugOverlay.show(text: string?)
	if not text then
		if label then
			label.Visible = false
		end
		return
	end
	if not label then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "HFFDebug"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 50
		gui.Parent = playerGui

		local newLabel = Instance.new("TextLabel")
		newLabel.AnchorPoint = Vector2.new(0.5, 0)
		newLabel.Position = UDim2.new(0.5, 0, 0, 70)
		newLabel.Size = UDim2.new(0.92, 0, 0, 210)
		newLabel.BackgroundColor3 = Color3.new(0, 0, 0)
		newLabel.BackgroundTransparency = 0.3
		newLabel.BorderSizePixel = 0
		newLabel.TextColor3 = Color3.new(1, 1, 1)
		newLabel.Font = Enum.Font.Code
		newLabel.TextSize = 16
		newLabel.TextWrapped = true
		newLabel.TextXAlignment = Enum.TextXAlignment.Left
		newLabel.TextYAlignment = Enum.TextYAlignment.Top
		newLabel.Parent = gui
		label = newLabel
	end
	label.Text = text
	label.Visible = true
end

return DebugOverlay
