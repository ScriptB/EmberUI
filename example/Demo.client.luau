-- EmberUI Demo
-- Place this in StarterPlayerScripts to test all elements.

local EmberUI = require(game.ReplicatedStorage.EmberUI)

local Win = EmberUI:Window({
	Title  = "Ember Demo",
	Width  = 680,
	Height = 530,
})

Win:SideButton("Discord", function()
	print("Discord clicked")
end)

Win:SideButton("Settings", function()
	print("Settings clicked")
end)

-- ── Farm Tab ────────────────────────────────────────────────────────────────
local Farm = Win:Tab("Farm")

local autoSection = Farm:Section("Auto Steal")

autoSection:Label({ Text = "Core controls and lifecycle examples" })
autoSection:Separator()

local autoSteal = autoSection:Toggle({
	Name     = "Auto Steal",
	Default  = false,
	Callback = function(v)
		print("Auto Steal:", v)
	end,
})

local instantSteal = autoSection:Toggle({
	Name     = "Instant Steal",
	Note     = "Delivers the egg in a few seconds — needs enough Speed",
	Default  = false,
	Callback = function(v)
		print("Instant Steal:", v)
	end,
})

local instantV2 = autoSection:Toggle({
	Name     = "Instant Steal V2",
	Default  = false,
	Callback = function(v) print("Instant Steal V2:", v) end,
})

local targetAreas = autoSection:Dropdown({
	Name     = "Target Areas",
	Options  = {
		"Sunflower Field", "Clover Field", "Strawberry Field",
		"Blueberry Field", "Bamboo Field", "Pine Tree Forest",
		"Mushroom Field", "Spider Field", "Stump Field",
		"Cactus Field", "Pumpkin Patch", "Rose Field", "Pineapple Patch",
	},
	Multi    = true,
	Default  = {},
	Callback = function(v)
		print("Areas selected:", #v)
	end,
})

local speedSlider = autoSection:Slider({
	Name     = "Steal Speed",
	Min      = 1,
	Max      = 200,
	Default  = 16,
	Suffix   = " WS",
	Callback = function(v)
		print("Speed:", v)
	end,
})

local progress = autoSection:Progress({ Name = "Setup progress", Value = 0.35 })
progress:Changed(function(value)
	print("Progress:", value)
end)

-- ── Player Tab ──────────────────────────────────────────────────────────────
local Player = Win:Tab("Player")

local playerSec = Player:Section("Movement")

playerSec:Slider({
	Name     = "Walk Speed",
	Min      = 16,
	Max      = 250,
	Default  = 16,
	Callback = function(v)
		local char = game.Players.LocalPlayer.Character
		if char and char:FindFirstChild("Humanoid") then
			char.Humanoid.WalkSpeed = v
		end
	end,
})

playerSec:Slider({
	Name     = "Jump Power",
	Min      = 7,
	Max      = 150,
	Default  = 7,
	Callback = function(v)
		local char = game.Players.LocalPlayer.Character
		if char and char:FindFirstChild("Humanoid") then
			char.Humanoid.JumpPower = v
		end
	end,
})

playerSec:Toggle({
	Name     = "Fly",
	Default  = false,
	Callback = function(v) print("Fly:", v) end,
})

playerSec:Button({
	Name     = "Respawn",
	Text     = "Respawn",
	Callback = function()
		game.Players.LocalPlayer.Character:BreakJoints()
	end,
})

-- ── Misc Tab ────────────────────────────────────────────────────────────────
local Misc = Win:Tab("Misc")

local miscSec = Misc:Section("Utilities")

miscSec:Input({
	Name        = "Custom Value",
	Placeholder = "Enter a number...",
	Numeric     = true,
	Callback    = function(v) print("Input:", v) end,
})

miscSec:Label({ Text = "EmberUI v2.0.1 — Lifecycle hotfix in progress" })

-- ── State example ────────────────────────────────────────────────────────────
local godState = EmberUI.State(false)
godState:Sub(function(v)
	print("God mode state changed:", v)
end)
