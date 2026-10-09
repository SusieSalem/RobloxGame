-- UIController
-- Builds the HUD: status badge, control hints, settings and touch buttons.

local RunService = game:GetService("RunService")

local Components = require(script.Parent.Components)
local Responsive = require(script.Parent.Responsive)
local StatusBadge = require(script.Parent.StatusBadge)
local ControlHints = require(script.Parent.ControlHints)
local SettingsMenu = require(script.Parent.SettingsMenu)
local TouchControls = require(script.Parent.TouchControls)

local HFF = script.Parent.Parent:WaitForChild("HFF")
local Shared = require(HFF.Shared)

local UIController = {}

function UIController.start(onRagdoll: () -> ())
	local playerGui = Shared.Player:WaitForChild("PlayerGui")

	local hud = Components.create("ScreenGui", {
		Name = "HFFHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	Responsive.attach(hud)

	local updateStatus = StatusBadge.mount(hud)
	ControlHints.mount(hud)
	SettingsMenu.mount(hud)
	TouchControls.mount(playerGui, onRagdoll)

	RunService.RenderStepped:Connect(function()
		updateStatus(Shared.State.rig)
	end)
end

return UIController
