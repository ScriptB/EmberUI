--!strict
-- Library composition layer. Shared systems live in sibling Core, Layout,
-- Managers, and Theme folders; UI construction remains here during migration.
--[[
	EmberUI  v2.0.1
	github.com/ScriptB/EmberUI

	local UI = require(script.Parent.EmberUI)
	local Win = UI:Window({ Title = "My Hub" })
	Win:SideButton("Discord", function() end)
	Win:Notify({ Title = "Ready", Message = "Loaded", Type = "success" })

	local Tab = Win:Tab("Farm")
	local Sec = Tab:Section("Auto Steal")
	Sec:Toggle({ Name = "Auto Steal", Default = false, Callback = function(v) end })
	Sec:Slider({ Name = "Speed", Min = 0, Max = 200, Default = 16, Suffix = " WS" })
	Sec:Dropdown({ Name = "Areas", Options = {"A","B"}, Multi = true })
	Sec:Button({ Name = "Go", Text = "Teleport", Callback = function() end })
	Sec:Input({ Name = "Value", Placeholder = "0..100" })
	Sec:Label({ Text = "Hello world" })
	Sec:Keybind({ Name = "Toggle Key", Default = Enum.KeyCode.RightShift })

	local s = UI.State(false)
	tog:Bind(s)

	Win:Search("filter")
	Win:Minimize()
	Win:Destroy()
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Root = script.Parent.Parent
local Core = Root.Core
local Maid = require(Core.Maid)
local State = require(Core.State)
local Signal = require(Core.Signal)
local Validation = require(Core.Validation)
local Logger = require(Core.Logger)
local WindowManager = require(Root.Managers.WindowManager)
local OverlayManager = require(Root.Managers.OverlayManager)
local ThemeManager = require(Root.Managers.ThemeManager)
local PersistenceManager = require(Root.Managers.PersistenceManager)
local Breakpoints = require(Root.Layout.Breakpoints)
local windowManager = WindowManager.new()

local function reportCallbackError(context, err)
	Logger.callbackError(context, err)
end

local function callCallback(context, callback, ...)
	if type(callback) ~= "function" then return end
	local args = table.pack(...)
	local ok, err = xpcall(function()
		callback(table.unpack(args, 1, args.n))
	end, debug.traceback)
	if not ok then reportCallbackError(context, err) end
end

-- ── Theme ─────────────────────────────────────────────────────────────────────
local T = require(Root.Theme.Tokens)
local themeManager = ThemeManager.new(T, {
	["Ember Dark"] = {},
	["Ember Light"] = require(Root.Theme.EmberLight),
	["Ember High Contrast"] = require(Root.Theme.EmberHighContrast),
})
local reducedMotion = false

-- ── Tween presets ─────────────────────────────────────────────────────────────
local TI_FAST   = TweenInfo.new(0.12, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.22, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out)
local TI_SPRING = TweenInfo.new(0.28, Enum.EasingStyle.Back,   Enum.EasingDirection.Out)
local TI_LINEAR = TweenInfo.new(1,    Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local function tw(obj, props, info)
	if reducedMotion then
		for property, value in pairs(props) do obj[property] = value end
		return
	end
	TweenService:Create(obj, info or TI_FAST, props):Play()
end

-- ── Primitives ────────────────────────────────────────────────────────────────
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end

-- Removes any existing UIStroke before adding a new one (prevents accumulation)
local function stroke(p, thick, col, trans)
	local e = p:FindFirstChildOfClass("UIStroke")
	if e then e:Destroy() end
	local s = Instance.new("UIStroke")
	s.Thickness       = thick or 1
	s.Color           = col   or T.Border
	s.Transparency    = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

-- Removes any existing UIGradient before adding a new one
local function grad(p, c0, c1, rot)
	local e = p:FindFirstChildOfClass("UIGradient")
	if e then e:Destroy() end
	local g = Instance.new("UIGradient")
	g.Color    = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent   = p
	return g
end

local function pad(p, l, r, t, b)
	local u = Instance.new("UIPadding")
	u.PaddingLeft   = UDim.new(0, l)
	u.PaddingRight  = UDim.new(0, r)
	u.PaddingTop    = UDim.new(0, t)
	u.PaddingBottom = UDim.new(0, b)
	u.Parent = p
	return u
end

local function list(p, dir, spacing)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding       = UDim.new(0, spacing or 0)
	l.SortOrder     = Enum.SortOrder.LayoutOrder
	l.Parent = p
	return l
end

local function mkFrame(props, parent)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	if props then for k, v in pairs(props) do (f::any)[k] = v end end
	if parent then f.Parent = parent end
	return f
end

local function mkLabel(props, parent)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font       = Enum.Font.GothamBold
	l.TextColor3 = T.Text
	l.TextSize   = 14
	l.TextScaled = false
	l.RichText   = false
	if props then for k, v in pairs(props) do (l::any)[k] = v end end
	if parent then l.Parent = parent end
	return l
end

local function mkButton(props, parent)
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Font            = Enum.Font.GothamBold
	b.TextColor3      = T.Text
	b.TextSize        = 14
	b.AutoButtonColor = false
	b.Selectable      = true
	b.Text            = ""
	if props then for k, v in pairs(props) do (b::any)[k] = v end end
	if parent then b.Parent = parent end
	return b
end

-- Solid-color rectangle that covers rounded corners on one side of a parent frame.
-- Used to make a frame appear to have corners only on the opposite side.
-- parent must have a solid BackgroundColor3 (no gradient) and a UICorner.
local function fixCorners(parent, side, col, h)
	h = h or 10
	local f = Instance.new("Frame")
	f.Name             = "_cornerFix"
	f.BorderSizePixel  = 0
	f.Size             = UDim2.new(1, 0, 0, h)
	f.Position         = (side == "bottom")
		and UDim2.new(0, 0, 1, -h)
		or  UDim2.new(0, 0, 0, 0)
	f.BackgroundColor3 = col
	f.ZIndex           = 1
	f.Parent           = parent
	return f
end

-- ── Dragging ──────────────────────────────────────────────────────────────────
local function makeDraggable(handle, target, maid, onMove)
	local dragging, dragStart, startPos = false, nil, nil
	maid:Give(handle.InputBegan:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		dragging  = true
		dragStart = inp.Position
		startPos  = target.Position
		inp.Changed:Connect(function()
			if inp.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end))
	maid:Give(UserInputService.InputChanged:Connect(function(inp)
		if not dragging or inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local d = inp.Position - dragStart
		target.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y
		)
		if onMove then onMove() end
	end))
end

local function makeResizable(target, maid, options, clampToViewport)
	local minWidth = options.MinWidth or 360
	local minHeight = options.MinHeight or 240
	local maxWidth = options.MaxWidth or 1600
	local maxHeight = options.MaxHeight or 1000
	local activeEdge, startPointer, startSize, startPosition = nil, nil, nil, nil
	local edges = {
		Left = { position = UDim2.new(0, -4, 0, 8), size = UDim2.new(0, 8, 1, -16) },
		Right = { position = UDim2.new(1, -4, 0, 8), size = UDim2.new(0, 8, 1, -16) },
		Top = { position = UDim2.new(0, 8, 0, -4), size = UDim2.new(1, -16, 0, 8) },
		Bottom = { position = UDim2.new(0, 8, 1, -4), size = UDim2.new(1, -16, 0, 8) },
		TopLeft = { position = UDim2.new(0, -5, 0, -5), size = UDim2.fromOffset(12, 12) },
		TopRight = { position = UDim2.new(1, -7, 0, -5), size = UDim2.fromOffset(12, 12) },
		BottomLeft = { position = UDim2.new(0, -5, 1, -7), size = UDim2.fromOffset(12, 12) },
		BottomRight = { position = UDim2.new(1, -7, 1, -7), size = UDim2.fromOffset(12, 12) },
	}
	for edge, layout in pairs(edges) do
		local handle = mkButton({ Name = "Resize" .. edge, Position = layout.position, Size = layout.size, ZIndex = 20 }, target)
		maid:Give(handle.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			activeEdge, startPointer, startSize, startPosition = edge, input.Position, target.Size, target.Position
			maid:Give(input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then activeEdge = nil end
			end))
		end))
	end
	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if not activeEdge or not startPointer or not startSize or not startPosition then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = input.Position - startPointer
		local left = activeEdge:find("Left", 1, true) ~= nil
		local right = activeEdge:find("Right", 1, true) ~= nil
		local top = activeEdge:find("Top", 1, true) ~= nil
		local bottom = activeEdge:find("Bottom", 1, true) ~= nil
		local width = math.clamp(startSize.X.Offset + (right and delta.X or (left and -delta.X or 0)), minWidth, maxWidth)
		local height = math.clamp(startSize.Y.Offset + (bottom and delta.Y or (top and -delta.Y or 0)), minHeight, maxHeight)
		local widthChange, heightChange = width - startSize.X.Offset, height - startSize.Y.Offset
		target.Size = UDim2.new(startSize.X.Scale, width, startSize.Y.Scale, height)
		target.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + (left and -widthChange / 2 or (right and widthChange / 2 or 0)), startPosition.Y.Scale, startPosition.Y.Offset + (top and -heightChange / 2 or (bottom and heightChange / 2 or 0)))
		clampToViewport()
	end))
end

-- ── Root ──────────────────────────────────────────────────────────────────────
local function getRoot()
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- ── Notification pool ─────────────────────────────────────────────────────────
local NOTIF_W, NOTIF_H, NOTIF_GAP = 300, 70, 6
local _notifGui = nil
local _notifs   = {}

local function ensureNotifGui()
	if _notifGui and _notifGui.Parent then return _notifGui end
	local g = Instance.new("ScreenGui")
	g.Name           = "EmberUI_Notifs"
	g.ResetOnSpawn   = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.IgnoreGuiInset = true
	g.Parent         = getRoot()
	_notifGui = g
	return g
end

local function repackNotifs()
	local y = 16
	for _, n in ipairs(_notifs) do
		if n and n.Parent then
			tw(n, { Position = UDim2.new(1, -(NOTIF_W + 16), 0, y) }, TI_MED)
			y = y + NOTIF_H + NOTIF_GAP
		end
	end
end

local function spawnNotif(cfg, ownerMaid)
	cfg = cfg or {}
	local title    = cfg.Title    or "Notice"
	local message  = cfg.Message  or ""
	local nType    = cfg.Type     or "info"
	local duration = cfg.Duration or 3.5

	local acCol, acDark = T.Info, T.InfoDark
	if nType == "success" then acCol = T.Success; acDark = T.SuccessDark
	elseif nType == "warn"    then acCol = T.Warn;    acDark = T.WarnDark
	elseif nType == "error"   then acCol = T.Error;   acDark = T.ErrorDark
	end

	local g = ensureNotifGui()

	local n = Instance.new("Frame")
	n.Size                  = UDim2.new(0, NOTIF_W, 0, NOTIF_H)
	n.Position              = UDim2.new(1, 16, 0, 16)
	n.BackgroundColor3      = T.SurfaceHi
	n.BackgroundTransparency= 0
	n.ZIndex                = 50
	n.Parent                = g
	if ownerMaid then ownerMaid:Give(n) end
	corner(n, 8)
	stroke(n, 1, T.Border)

	-- Accent bar (left edge)
	local bar = Instance.new("Frame")
	bar.Size             = UDim2.new(0, 3, 1, -16)
	bar.Position         = UDim2.new(0, 0, 0, 8)
	bar.BackgroundColor3 = acCol
	bar.BorderSizePixel  = 0
	bar.ZIndex           = 51
	bar.Parent           = n
	corner(bar, 2)
	grad(bar, acCol, acDark, 90)

	mkLabel({
		Position       = UDim2.new(0, 14, 0, 10),
		Size           = UDim2.new(1, -60, 0, 18),
		Text           = title,
		TextSize       = 14,
		Font           = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex         = 51,
	}, n)

	mkLabel({
		Position       = UDim2.new(0, 14, 0, 30),
		Size           = UDim2.new(1, -18, 0, 32),
		Text           = message,
		TextSize       = 11,
		Font           = Enum.Font.Gotham,
		TextColor3     = T.TextSub,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped    = true,
		ZIndex         = 51,
	}, n)

	mkLabel({
		AnchorPoint    = Vector2.new(1, 0),
		Position       = UDim2.new(1, -10, 0, 8),
		Size           = UDim2.new(0, 58, 0, 16),
		Text           = nType:upper(),
		TextSize       = 10,
		Font           = Enum.Font.GothamBlack,
		TextColor3     = acCol,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex         = 51,
	}, n)

	-- Progress drain bar
	local prog = Instance.new("Frame")
	prog.AnchorPoint      = Vector2.new(0, 1)
	prog.Position         = UDim2.new(0, 0, 1, 0)
	prog.Size             = UDim2.new(1, 0, 0, 2)
	prog.BackgroundColor3 = acCol
	prog.BorderSizePixel  = 0
	prog.ZIndex           = 52
	prog.Parent           = n
	TweenService:Create(n, TweenInfo.new(0, Enum.EasingStyle.Linear), {}):Play()
	tw(prog, { Size = UDim2.new(0, 0, 0, 2) },
		TweenInfo.new(duration, Enum.EasingStyle.Linear))

	table.insert(_notifs, n)
	repackNotifs()

	task.delay(duration, function()
		if not (n and n.Parent) then return end
		local exitY = n.Position.Y.Offset
		tw(n, { Position = UDim2.new(1, 16, 0, exitY) }, TI_MED)
		task.wait(0.25)
		for i, v in ipairs(_notifs) do
			if v == n then table.remove(_notifs, i); break end
		end
		n:Destroy()
		repackNotifs()
	end)
end

-- ══════════════════════════════════════════════════════════════════════════════
--  buildWindow
-- ══════════════════════════════════════════════════════════════════════════════
local function buildWindow(cfg)
	cfg         = cfg or {}
	if type(cfg) ~= "table" then error("EmberUI:Window expects a configuration table", 2) end
	Validation.warnUnknown(cfg, { "Id", "Title", "Width", "Height", "MinWidth", "MinHeight", "MaxWidth", "MaxHeight", "Scale", "Singleton" }, "Window")
	cfg.Title   = cfg.Title  or "EmberUI"
	cfg.Width   = cfg.Width  or 660
	cfg.Height  = cfg.Height or 520
	if type(cfg.Title) ~= "string" then error("EmberUI:Window Title must be a string", 2) end
	if type(cfg.Width) ~= "number" or cfg.Width <= 0 then error("EmberUI:Window Width must be a positive number", 2) end
	if type(cfg.Height) ~= "number" or cfg.Height <= 0 then error("EmberUI:Window Height must be a positive number", 2) end
	if cfg.Scale ~= nil and (type(cfg.Scale) ~= "number" or cfg.Scale < 0.75 or cfg.Scale > 1.5) then error("EmberUI:Window Scale must be between 0.75 and 1.5", 2) end
	for _, property in ipairs({ "MinWidth", "MinHeight", "MaxWidth", "MaxHeight" }) do
		if cfg[property] ~= nil and (type(cfg[property]) ~= "number" or cfg[property] <= 0) then error("EmberUI:Window " .. property .. " must be a positive number", 2) end
	end
	if cfg.MinWidth and cfg.MaxWidth and cfg.MinWidth > cfg.MaxWidth then error("EmberUI:Window MinWidth must not exceed MaxWidth", 2) end
	if cfg.MinHeight and cfg.MaxHeight and cfg.MinHeight > cfg.MaxHeight then error("EmberUI:Window MinHeight must not exceed MaxHeight", 2) end
	local windowMaid = Maid.new()
	local overlayManager = OverlayManager.new(windowMaid)
	local Window: any = nil
	local gui: ScreenGui? = nil
	local destroyed = false
	local function destroyWindow()
		if destroyed then return end
		destroyed = true
		windowMaid:Destroy()
		if gui then themeManager:Unregister(gui) end
		if Window then windowManager:Unregister(Window) end
	end

	local TOPBAR_H  = 44
	local SEARCH_H  = 38
	local SIDEBAR_W = 130
	local SIDEBAR_GAP = 6

	-- ScreenGui
	gui = Instance.new("ScreenGui")
	gui.Name           = "EmberUI_" .. cfg.Title:gsub("%s", "")
	gui.ResetOnSpawn   = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent         = getRoot()
	windowMaid:Give(gui)
	themeManager:Register(gui)

	-- Main frame
	local win = Instance.new("Frame")
	win.Name                  = "Window"
	win.AnchorPoint           = Vector2.new(0.5, 0.5)
	win.Position              = UDim2.new(0.5, 0, 0.5, 0)
	win.Size                  = UDim2.new(0, cfg.Width, 0, cfg.Height)
	win.BackgroundColor3      = T.Bg
	win.BackgroundTransparency= 0
	win.ClipsDescendants      = false
	win.Parent                = gui
	corner(win, 10)
	stroke(win, 1, T.Border)
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = cfg.Scale or 1
	uiScale.Parent = win
	local function clampToViewport()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		local halfWidth = math.max(0, (viewport.X - win.AbsoluteSize.X) / 2)
		local halfHeight = math.max(0, (viewport.Y - win.AbsoluteSize.Y) / 2)
		win.Position = UDim2.new(win.Position.X.Scale, math.clamp(win.Position.X.Offset, -halfWidth, halfWidth), win.Position.Y.Scale, math.clamp(win.Position.Y.Offset, -halfHeight, halfHeight))
	end
	makeResizable(win, windowMaid, cfg, clampToViewport)
	task.defer(clampToViewport)
	if workspace.CurrentCamera then
		windowMaid:Give(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(clampToViewport))
	end

	-- ── TopBar ────────────────────────────────────────────────────────────────
	-- Solid SurfaceHi with UICorner(10) + fixCorners("bottom") = top-rounded only
	local topBar = Instance.new("Frame")
	topBar.Name             = "TopBar"
	topBar.Size             = UDim2.new(1, 0, 0, TOPBAR_H)
	topBar.BackgroundColor3 = T.SurfaceHi
	topBar.ZIndex           = 6
	topBar.Parent           = win
	corner(topBar, 10)
	fixCorners(topBar, "bottom", T.SurfaceHi)

	-- Thin accent line along the bottom of the topbar
	mkFrame({
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0.04, 0, 1, 0),
		Size             = UDim2.new(0.92, 0, 0, 1),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0.45,
		ZIndex           = 7,
	}, topBar)

	-- Ember dot logo
	local logoDot = Instance.new("Frame")
	logoDot.Size             = UDim2.new(0, 9, 0, 9)
	logoDot.Position         = UDim2.new(0, 15, 0.5, 0)
	logoDot.AnchorPoint      = Vector2.new(0, 0.5)
	logoDot.BackgroundColor3 = T.Accent
	logoDot.ZIndex           = 8
	logoDot.Parent           = topBar
	corner(logoDot, 5)
	grad(logoDot, T.AccentBright, T.AccentDark, 135)

	-- Title
	mkLabel({
		Position       = UDim2.new(0, 30, 0, 0),
		Size           = UDim2.new(1, -112, 1, 0),
		Text           = cfg.Title,
		Font           = Enum.Font.GothamBlack,
		TextSize       = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex         = 7,
	}, topBar)

	-- Minimize button
	local minimizeBtn = mkButton({
		Size             = UDim2.new(0, 27, 0, 27),
		Position         = UDim2.new(1, -74, 0.5, 0),
		AnchorPoint      = Vector2.new(0, 0.5),
		BackgroundColor3 = T.SurfaceHover,
		BackgroundTransparency = 0,
		Text             = "—",
		TextSize         = 11,
		TextColor3       = T.TextSub,
		ZIndex           = 8,
	}, topBar)
	corner(minimizeBtn, 6)
	stroke(minimizeBtn, 1, T.Border)
	minimizeBtn.MouseEnter:Connect(function() tw(minimizeBtn, { BackgroundColor3 = T.BorderHi }) end)
	minimizeBtn.MouseLeave:Connect(function() tw(minimizeBtn, { BackgroundColor3 = T.SurfaceHover }) end)

	-- Close button
	local closeBtn = mkButton({
		Size             = UDim2.new(0, 27, 0, 27),
		Position         = UDim2.new(1, -40, 0.5, 0),
		AnchorPoint      = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(190, 45, 45),
		BackgroundTransparency = 0,
		Text             = "✕",
		TextSize         = 12,
		TextColor3       = T.Text,
		ZIndex           = 8,
	}, topBar)
	corner(closeBtn, 6)
	stroke(closeBtn, 1, Color3.fromRGB(120, 22, 22))
	closeBtn.MouseEnter:Connect(function() tw(closeBtn, { BackgroundColor3 = Color3.fromRGB(228, 60, 60) }) end)
	closeBtn.MouseLeave:Connect(function() tw(closeBtn, { BackgroundColor3 = Color3.fromRGB(190, 45, 45) }) end)
	closeBtn.Activated:Connect(destroyWindow)

	makeDraggable(topBar, win, windowMaid, clampToViewport)

	-- Minimize logic
	local minimized = false
	local restoredSize = win.Size
	local function doMinimize()
		minimized = not minimized
		if minimized then restoredSize = win.Size end
		for _, ch in ipairs(win:GetChildren()) do
			if ch ~= topBar and ch:IsA("GuiObject") then
				ch.Visible = not minimized
			end
		end
		tw(win, {
			Size = minimized
				and UDim2.new(restoredSize.X.Scale, restoredSize.X.Offset, 0, TOPBAR_H + 2)
				or restoredSize
		}, TI_MED)
		minimizeBtn.Text = minimized and "+" or "-"
	end
	minimizeBtn.Activated:Connect(doMinimize)

	-- ── Left sidebar (ScrollingFrame for overflow) ────────────────────────────
	local leftSide = Instance.new("ScrollingFrame")
	leftSide.Name                   = "LeftSidebar"
	leftSide.AnchorPoint            = Vector2.new(1, 0)
	leftSide.Position               = UDim2.new(0, -SIDEBAR_GAP, 0, TOPBAR_H)
	leftSide.Size                   = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H)
	leftSide.BackgroundColor3       = T.Bg
	leftSide.BackgroundTransparency = 0
	leftSide.ScrollBarThickness     = 3
	leftSide.ScrollBarImageColor3   = T.Accent
	leftSide.CanvasSize             = UDim2.new(0, 0, 0, 0)
	leftSide.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	leftSide.ClipsDescendants       = true
	leftSide.ZIndex                 = 3
	leftSide.Parent                 = win
	corner(leftSide, 8)
	stroke(leftSide, 1, T.Border)
	pad(leftSide, 6, 6, 8, 8)
	list(leftSide, Enum.FillDirection.Vertical, 4)

	-- ── Right sidebar ────────────────────────────────────────────────────────
	local rightSide = Instance.new("Frame")
	rightSide.Name                   = "RightSidebar"
	rightSide.Position               = UDim2.new(1, SIDEBAR_GAP, 0, TOPBAR_H)
	rightSide.Size                   = UDim2.new(0, SIDEBAR_W, 0, 0)
	rightSide.AutomaticSize          = Enum.AutomaticSize.Y
	rightSide.BackgroundColor3       = T.Bg
	rightSide.BackgroundTransparency = 0
	rightSide.ClipsDescendants       = true
	rightSide.ZIndex                 = 3
	rightSide.Parent                 = win
	corner(rightSide, 8)
	stroke(rightSide, 1, T.Border)
	pad(rightSide, 6, 6, 8, 8)
	list(rightSide, Enum.FillDirection.Vertical, 4)

	-- ── Content area ─────────────────────────────────────────────────────────
	local contentArea = mkFrame({
		Name     = "Content",
		Position = UDim2.new(0, 0, 0, TOPBAR_H),
		Size     = UDim2.new(1, 0, 1, -(TOPBAR_H + SEARCH_H)),
		ZIndex   = 2,
	}, win)

	local pages = mkFrame({ Name = "Pages", Size = UDim2.new(1, 0, 1, 0) }, contentArea)

	-- ── Search bar ───────────────────────────────────────────────────────────
	-- Solid SurfaceHi + UICorner(10) + fixCorners("top") = bottom-rounded only
	local searchBar = Instance.new("Frame")
	searchBar.Name                  = "SearchBar"
	searchBar.AnchorPoint           = Vector2.new(0, 1)
	searchBar.Position              = UDim2.new(0, 0, 1, 0)
	searchBar.Size                  = UDim2.new(1, 0, 0, SEARCH_H)
	searchBar.BackgroundColor3      = T.SurfaceHi
	searchBar.BackgroundTransparency= 0
	searchBar.ZIndex                = 6
	searchBar.Parent                = win
	corner(searchBar, 10)
	fixCorners(searchBar, "top", T.SurfaceHi)
	stroke(searchBar, 1, T.Border)

	-- Thin accent line at top of search bar
	mkFrame({
		Position         = UDim2.new(0.04, 0, 0, 0),
		Size             = UDim2.new(0.92, 0, 0, 1),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0.5,
		ZIndex           = 7,
	}, searchBar)

	-- Search icon: two plain Frames forming a magnifier circle + handle
	local searchDot = Instance.new("Frame")
	searchDot.Size             = UDim2.new(0, 11, 0, 11)
	searchDot.Position         = UDim2.new(0, 13, 0.5, 0)
	searchDot.AnchorPoint      = Vector2.new(0, 0.5)
	searchDot.BackgroundTransparency = 1
	searchDot.ZIndex           = 7
	searchDot.Parent           = searchBar
	local sdCircle = Instance.new("Frame")
	sdCircle.Size             = UDim2.new(0, 8, 0, 8)
	sdCircle.BackgroundTransparency = 1
	sdCircle.BorderSizePixel  = 0
	sdCircle.ZIndex           = 7
	sdCircle.Parent           = searchDot
	corner(sdCircle, 4)
	stroke(sdCircle, 1.5, T.TextHint)
	local sdHandle = Instance.new("Frame")
	sdHandle.Size             = UDim2.new(0, 1.5, 0, 5)
	sdHandle.Position         = UDim2.new(0, 8, 0, 7)
	sdHandle.Rotation         = 45
	sdHandle.BackgroundColor3 = T.TextHint
	sdHandle.BorderSizePixel  = 0
	sdHandle.ZIndex           = 7
	sdHandle.Parent           = searchDot

	mkFrame({
		Size             = UDim2.new(0, 1, 0.55, 0),
		Position         = UDim2.new(0, 30, 0.225, 0),
		BackgroundColor3 = T.Border,
		BackgroundTransparency = 0,
		ZIndex           = 7,
	}, searchBar)

	local searchBox = Instance.new("TextBox")
	searchBox.Text              = ""
	searchBox.Size              = UDim2.new(1, -42, 1, -12)
	searchBox.Position          = UDim2.new(0, 36, 0, 6)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText   = "Search features..."
	searchBox.PlaceholderColor3 = T.TextHint
	searchBox.TextColor3        = T.Text
	searchBox.Font              = Enum.Font.Gotham
	searchBox.TextSize          = 13
	searchBox.TextXAlignment    = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus  = false
	searchBox.ZIndex            = 7
	searchBox.Parent            = searchBar

	-- ════════════════════════════════════════════════════════════════════════
	--  Window object
	-- ════════════════════════════════════════════════════════════════════════
	Window = {}
	Window._tabs        = {}
	Window._activeTab   = nil
	Window._allElements = {}
	Window._gui         = gui
	Window._win         = win
	Window._maid        = windowMaid
	Window._ids         = {}
	Window.Id           = nil

	function Window:_validateControlId(config, kind)
		local id = config.Id
		if id == nil then return end
		if type(id) ~= "string" or id == "" then
			error(("EmberUI %s Id must be a non-empty string"):format(kind), 3)
		end
		if self._ids[id] then
			error(("EmberUI duplicate control Id '%s'"):format(id), 3)
		end
	end

	function Window:_registerControl(ctrl, config, kind)
		local id = config.Id
		if id ~= nil then
			if type(id) ~= "string" or id == "" then
				error(("EmberUI %s Id must be a non-empty string"):format(kind), 3)
			end
			if self._ids[id] then
				error(("EmberUI duplicate control Id '%s'"):format(id), 3)
			end
			self._ids[id] = ctrl
			ctrl.Id = id
		end
		table.insert(self._allElements, ctrl)
		return ctrl
	end
	function Window:_unregisterControl(ctrl)
		if ctrl.Id and self._ids[ctrl.Id] == ctrl then self._ids[ctrl.Id] = nil end
		for index, current in ipairs(self._allElements) do
			if current == ctrl then table.remove(self._allElements, index); break end
		end
	end

	function Window:Notify(c) spawnNotif(c, self._maid) end
	function Window:Destroy()
		destroyWindow()
	end
	function Window:Close() self:Destroy() end
	function Window:IsDestroyed() return destroyed end
	function Window:Minimize() doMinimize() end
	function Window:Restore() if minimized then doMinimize() end end
	function Window:Toggle()
		win.Visible = not win.Visible
		if win.Visible then self:BringToFront() end
	end
	function Window:BringToFront() windowManager:BringToFront(self) end
	function Window:SetVisible(visible: boolean)
		win.Visible = visible
		if visible then self:BringToFront() end
	end
	function Window:SetPosition(position: UDim2) win.Position = position end
	function Window:SetSize(size: UDim2) win.Size = size end
	function Window:GetPosition() return win.Position end
	function Window:GetSize() return win.Size end
	function Window:SetScale(scale)
		if type(scale) ~= "number" or scale < 0.75 or scale > 1.5 then error("EmberUI Window:SetScale expects 0.75–1.5", 2) end
		uiScale.Scale = scale
		clampToViewport()
	end
	function Window:GetScale() return uiScale.Scale end
	function Window:GetBreakpoint() return Breakpoints.Get(win.AbsoluteSize.X) end
	local breakpointChanged = Signal.new()
	local currentBreakpoint = Window:GetBreakpoint()
	windowMaid:Give(win:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local nextBreakpoint = Window:GetBreakpoint()
		if nextBreakpoint ~= currentBreakpoint then
			currentBreakpoint = nextBreakpoint
			breakpointChanged:Fire(nextBreakpoint)
		end
	end))
	function Window:BreakpointChanged(callback) return breakpointChanged:Connect(callback) end
	windowMaid:Give(function() breakpointChanged:Destroy() end)

	windowMaid:Give(win.InputBegan:Connect(function()
		Window:BringToFront()
	end))

	-- ── SideButton ───────────────────────────────────────────────────────────
	function Window:SideButton(name2, callback)
		local btn = mkButton({
			Name             = name2,
			Size             = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = T.Accent,
			BackgroundTransparency = 0,
			ZIndex           = 4,
		}, rightSide)
		corner(btn, 7)
		grad(btn, T.AccentBright, T.AccentDark, 90)
		stroke(btn, 1, T.AccentDark)
		mkLabel({ Size = UDim2.new(1, 0, 1, 0), Text = name2, TextSize = 13, ZIndex = 5 }, btn)
		btn.MouseEnter:Connect(function() tw(btn, { BackgroundColor3 = T.AccentBright }) end)
		btn.MouseLeave:Connect(function() tw(btn, { BackgroundColor3 = T.Accent }) end)
		btn.Activated:Connect(function() callCallback("SideButton", callback) end)
		return btn
	end

	-- ── Tab ──────────────────────────────────────────────────────────────────
	function Window:Tab(name2)
		-- Declare Tab first so activate() can reference it safely
		local Tab = { _btn = nil, _page = nil, _win = Window }

		local tabBtn = mkButton({
			Name             = name2,
			Size             = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = T.SurfaceHi,
			BackgroundTransparency = 0,
			ZIndex           = 4,
		}, leftSide)
		corner(tabBtn, 7)
		stroke(tabBtn, 1, T.Border)
		Tab._btn = tabBtn

		-- Active left-edge indicator bar
		local activeBar = mkFrame({
			Name             = "_activeBar",
			Size             = UDim2.new(0, 3, 0.55, 0),
			Position         = UDim2.new(0, 0, 0.225, 0),
			BackgroundColor3 = T.Accent,
			BackgroundTransparency = 1,
			ZIndex           = 6,
		}, tabBtn)
		corner(activeBar, 2)
		grad(activeBar, T.AccentBright, T.AccentDark, 90)

		mkLabel({
			Position       = UDim2.new(0, 10, 0, 0),
			Size           = UDim2.new(1, -10, 1, 0),
			Text           = name2,
			TextSize       = 13,
			Font           = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex         = 5,
		}, tabBtn)

		-- Tab page (scrollable)
		local page = Instance.new("ScrollingFrame")
		page.Name                   = name2 .. "_Page"
		page.Size                   = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.ScrollBarThickness     = 4
		page.ScrollBarImageColor3   = T.Accent
		page.CanvasSize             = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize    = Enum.AutomaticSize.Y
		page.Visible                = false
		page.ZIndex                 = 3
		page.Parent                 = pages
		pad(page, 10, 14, 8, 8)
		list(page, Enum.FillDirection.Vertical, 6)
		Tab._page = page

		local function activate()
			if Window._activeTab == Tab then return end
			-- Deactivate old
			if Window._activeTab then
				local old = Window._activeTab
				old._page.Visible = false
				tw(old._btn, { BackgroundColor3 = T.SurfaceHi })
				stroke(old._btn, 1, T.Border)
				local g = old._btn:FindFirstChildOfClass("UIGradient")
				if g then g:Destroy() end
				local ab = old._btn:FindFirstChild("_activeBar")
				if ab then tw(ab, { BackgroundTransparency = 1 }) end
				for _, ch in ipairs(old._btn:GetChildren()) do
					if ch:IsA("TextLabel") then tw(ch, { TextColor3 = T.Text }) end
				end
			end
			-- Activate this
			page.Visible = true
			tw(tabBtn, { BackgroundColor3 = T.AccentDark })
			grad(tabBtn, T.AccentMid, T.AccentDark, 90)
			stroke(tabBtn, 1, T.AccentDark)
			tw(activeBar, { BackgroundTransparency = 0 })
			Window._activeTab = Tab
		end

		tabBtn.Activated:Connect(activate)
		tabBtn.MouseEnter:Connect(function()
			if Window._activeTab ~= Tab then tw(tabBtn, { BackgroundColor3 = T.SurfaceHover }) end
		end)
		tabBtn.MouseLeave:Connect(function()
			if Window._activeTab ~= Tab then tw(tabBtn, { BackgroundColor3 = T.SurfaceHi }) end
		end)

		if #Window._tabs == 0 then task.defer(activate) end
		table.insert(Window._tabs, Tab)

		-- ── Section ──────────────────────────────────────────────────────────
		function Tab:Section(sname, expanded)
			if expanded == nil then expanded = true end

			-- Wrapper: solid Surface + UICorner(8) + UIStroke
			local secWrap = Instance.new("Frame")
			secWrap.Name                  = sname .. "_Sec"
			secWrap.Size                  = UDim2.new(1, 0, 0, 0)
			secWrap.AutomaticSize         = Enum.AutomaticSize.Y
			secWrap.BackgroundColor3      = T.SurfaceHi
			secWrap.BackgroundTransparency= 0
			secWrap.ZIndex                = 4
			secWrap.Parent                = page
			corner(secWrap, 8)
			stroke(secWrap, 1, T.Border, 0.55)
			list(secWrap, Enum.FillDirection.Vertical, 0)

			-- Header: SurfaceHi + UICorner(8) + fixCorners("bottom") = top-rounded only
			local hdr = Instance.new("Frame")
			hdr.Name             = "Header"
			hdr.LayoutOrder      = 0
			hdr.Size             = UDim2.new(1, 0, 0, 34)
			hdr.BackgroundColor3 = T.Surface
			hdr.ZIndex           = 5
			hdr.Parent           = secWrap
			corner(hdr, 8)
			fixCorners(hdr, "bottom", T.Surface, 9)

			-- Bottom separator line of header
			mkFrame({
				AnchorPoint      = Vector2.new(0, 1),
				Position         = UDim2.new(0, 0, 1, 0),
				Size             = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = T.Border,
				BackgroundTransparency = 0.72,
				ZIndex           = 6,
			}, hdr)

			-- Frame-based chevron: two thin bars forming ">" rotated 90° when open
			-- Using frames avoids Roblox font Unicode coverage gaps
			local chevWrap = Instance.new("Frame")
			chevWrap.Name             = "_chevron"
			chevWrap.Size             = UDim2.new(0, 10, 0, 10)
			chevWrap.Position         = UDim2.new(0, 12, 0.5, 0)
			chevWrap.AnchorPoint      = Vector2.new(0, 0.5)
			chevWrap.BackgroundTransparency = 1
			chevWrap.Rotation         = expanded and 90 or 0
			chevWrap.ZIndex           = 6
			chevWrap.Parent           = hdr
			local chevA = Instance.new("Frame")
			chevA.Size             = UDim2.new(0, 6, 0, 1.5)
			chevA.Position         = UDim2.new(0, 0, 0.5, -3)
			chevA.Rotation         = 40
			chevA.BackgroundColor3 = T.Accent
			chevA.BorderSizePixel  = 0
			chevA.ZIndex           = 6
			chevA.Parent           = chevWrap
			corner(chevA, 1)
			local chevB = Instance.new("Frame")
			chevB.Size             = UDim2.new(0, 6, 0, 1.5)
			chevB.Position         = UDim2.new(0, 0, 0.5, 2)
			chevB.Rotation         = -40
			chevB.BackgroundColor3 = T.Accent
			chevB.BorderSizePixel  = 0
			chevB.ZIndex           = 6
			chevB.Parent           = chevWrap
			corner(chevB, 1)
			local chevron = chevWrap  -- used below for the toggle

			mkLabel({
				Position       = UDim2.new(0, 28, 0, 0),
				Size           = UDim2.new(1, -34, 1, 0),
				Text           = sname,
				TextSize       = 13,
				Font           = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex         = 6,
			}, hdr)

			local hdrHit = mkButton({ Size = UDim2.new(1, 0, 1, 0), ZIndex = 7 }, hdr)

			local contentFrame = mkFrame({
				Name          = "Content",
				LayoutOrder   = 1,
				Size          = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible       = expanded,
				ZIndex        = 4,
			}, secWrap)
			pad(contentFrame, 8, 8, 5, 5)
			list(contentFrame, Enum.FillDirection.Vertical, 2)

			hdrHit.Activated:Connect(function()
				contentFrame.Visible = not contentFrame.Visible
				tw(chevron, { Rotation = contentFrame.Visible and 90 or 0 }, TI_FAST)
			end)

			-- ── Section object ────────────────────────────────────────────────
			local Section = { _content = contentFrame, _elements = {} }

			local function makeRow(rname, h)
				local row = Instance.new("Frame")
				row.Name                  = rname
				row.Size                  = UDim2.new(1, 0, 0, h)
				row.BackgroundColor3      = T.SurfaceHi
				row.BackgroundTransparency= 1
				row.ZIndex                = 5
				row.Parent                = contentFrame
				mkFrame({
					Size             = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = T.Border,
					BackgroundTransparency = 0.84,
					ZIndex           = 6,
				}, row)
				return row
			end

			local function rowNameLabel(row, text, xOff)
				return mkLabel({
					Position       = UDim2.new(0, xOff or 14, 0, 0),
					Size           = UDim2.new(0.52, 0, 1, 0),
					Text           = text,
					TextSize       = 13,
					Font           = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 6,
				}, row)
			end

			function Section:Separator(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Separator")
				Validation.warnUnknown(c2, { "Id", "Visible" }, "Separator")
				local row = makeRow("Separator", 13)
				row.BackgroundTransparency = 1
				mkFrame({ Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = T.Border, BackgroundTransparency = 0.25, ZIndex = 6 }, row)
				local ctrl = { _row = row, _name = "Separator" }
				function ctrl:Destroy() Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(visible) row.Visible = visible end
				Window:_registerControl(ctrl, c2, "Separator")
				return ctrl
			end

			function Section:Spacer(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Spacer")
				Validation.warnUnknown(c2, { "Id", "Height", "Visible" }, "Spacer")
				local height = c2.Height or 8
				if type(height) ~= "number" or height < 0 then error("EmberUI Spacer Height must be a non-negative number", 2) end
				local row = makeRow("Spacer", height)
				row.BackgroundTransparency = 1
				local ctrl = { _row = row, _name = "Spacer" }
				function ctrl:Destroy() Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(visible) row.Visible = visible end
				Window:_registerControl(ctrl, c2, "Spacer")
				return ctrl
			end

			function Section:Progress(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Progress")
				Validation.warnUnknown(c2, { "Id", "Name", "Value", "Visible" }, "Progress")
				local value = math.clamp(tonumber(c2.Value) or 0, 0, 1)
				local changed = Signal.new()
				local row = makeRow(c2.Name or "Progress", 42)
				rowNameLabel(row, c2.Name or "Progress")
				local track = mkFrame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 158, 0, 8), BackgroundColor3 = T.SurfaceHover, BackgroundTransparency = 0, ZIndex = 6 }, row)
				corner(track, 4)
				local fill = mkFrame({ Size = UDim2.new(value, 0, 1, 0), BackgroundColor3 = T.Accent, BackgroundTransparency = 0, ZIndex = 7 }, track)
				corner(fill, 4)
				local ctrl = { _row = row, _name = c2.Name or "Progress" }
				function ctrl:Get() return value end
				function ctrl:Changed(callback) return changed:Connect(callback) end
				function ctrl:Set(nextValue, fire)
					if type(nextValue) ~= "number" then error("EmberUI Progress:Set expects a number", 2) end
					value = math.clamp(nextValue, 0, 1)
					tw(fill, { Size = UDim2.new(value, 0, 1, 0) }, TI_FAST)
					if fire ~= false then changed:Fire(value) end
				end
				function ctrl:SetVisible(visible) row.Visible = visible end
				function ctrl:Destroy() changed:Destroy(); Window:_unregisterControl(self); row:Destroy() end
				Window:_registerControl(ctrl, c2, "Progress")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── TOGGLE ───────────────────────────────────────────────────────
			function Section:Toggle(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Toggle")
				Validation.warnUnknown(c2, { "Id", "Name", "Note", "Default", "Disabled", "Callback" }, "Toggle")
				local tName  = c2.Name     or "Toggle"
				local tDef   = c2.Default  or false
				local tCb    = c2.Callback
				local hasNote= c2.Note ~= nil

				local ROW_H = hasNote and 54 or 42
				local row = makeRow(tName, ROW_H)

				local nLbl = rowNameLabel(row, tName)
				if hasNote then
					nLbl.Size     = UDim2.new(0.65, 0, 0, 22)
					nLbl.Position = UDim2.new(0, 14, 0, 6)
					mkLabel({
						Position       = UDim2.new(0, 14, 0, 28),
						Size           = UDim2.new(0.8, 0, 0, 18),
						Text           = c2.Note,
						TextSize       = 11,
						TextColor3     = T.TextSub,
						Font           = Enum.Font.Gotham,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex         = 6,
					}, row)
				end

				-- Pill switch
				local PW, PH = 44, 22
				local KS = PH - 6

				local pill = Instance.new("Frame")
				pill.AnchorPoint      = Vector2.new(1, 0.5)
				pill.Position         = UDim2.new(1, -14, 0.5, 0)
				pill.Size             = UDim2.new(0, PW, 0, PH)
				pill.BackgroundColor3 = T.Off
				pill.ZIndex           = 7
				pill.Parent           = row
				corner(pill, PH)
				stroke(pill, 1, T.OffDark)

				local knob = Instance.new("Frame")
				knob.AnchorPoint      = Vector2.new(0, 0.5)
				knob.Position         = UDim2.new(0, 3, 0.5, 0)
				knob.Size             = UDim2.new(0, KS, 0, KS)
				knob.BackgroundColor3 = Color3.fromRGB(195, 195, 208)
				knob.ZIndex           = 8
				knob.Parent           = pill
				corner(knob, KS)

				local hit = mkButton({ Size = UDim2.new(1, 0, 1, 0), ZIndex = 9 }, row)

				local value = tDef
				local _boundState = nil
				local _unsubscribe = nil
				local destroyed = false
				local disabled = c2.Disabled == true
				local changed = Signal.new()

				local function applyToggle(v, fire)
					value = v
					local toPos = v
						and UDim2.new(0, PW - KS - 3, 0.5, 0)
						or  UDim2.new(0, 3, 0.5, 0)
					tw(knob, { Position = toPos }, TI_SPRING)
					tw(pill, { BackgroundColor3 = v and T.On or T.Off }, TI_FAST)
					tw(knob, { BackgroundColor3 = v and T.OnBright or Color3.fromRGB(195, 195, 208) }, TI_FAST)
					stroke(pill, 1, v and T.OnDark or T.OffDark)
					if fire ~= false then
						callCallback("Toggle", tCb, v)
						changed:Fire(v)
					end
					if _boundState then _boundState:Set(v) end
				end

				applyToggle(tDef, false)
				hit.Active = not disabled
				if disabled then pill.BackgroundTransparency = 0.45 end
				hit.Activated:Connect(function()
					if not disabled then applyToggle(not value) end
				end)

				-- Runtime-settable note
				local dynNote = mkLabel({
					Name           = "_dynNote",
					Position       = UDim2.new(0, 14, 0, hasNote and 28 or 0),
					Size           = UDim2.new(0.8, 0, 0, 16),
					TextSize       = 11,
					TextColor3     = T.TextSub,
					Font           = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					Visible        = false,
					ZIndex         = 6,
				}, row)

				local ctrl = { _row = row, _name = tName }
				function ctrl:Set(v, fire)
					if destroyed then return end
					applyToggle(v, fire)
				end
				function ctrl:Get() return value end
				function ctrl:Changed(callback) return changed:Connect(callback) end
				function ctrl:SetDisabled(nextDisabled)
					disabled = nextDisabled == true
					hit.Active = not disabled
					pill.BackgroundTransparency = disabled and 0.45 or 0
				end
				function ctrl:SetNote(txt)
					dynNote.Text    = txt
					dynNote.Visible = txt ~= ""
					row.Size = UDim2.new(1, 0, 0, txt ~= "" and 54 or 42)
				end
				function ctrl:GetNote() return dynNote.Text end
				function ctrl:Bind(state)
					self:Unbind()
					_boundState = state
					local subscribe = state.Subscribe or state.Sub
					if type(subscribe) ~= "function" or type(state.Get) ~= "function" then
						error("EmberUI Toggle:Bind expects a State with Get and Subscribe/Sub", 2)
					end
					_unsubscribe = subscribe(state, function(v)
						if not destroyed then applyToggle(v, false) end
					end)
					applyToggle(state:Get(), false)
				end
				function ctrl:Unbind()
					if _unsubscribe then _unsubscribe(); _unsubscribe = nil end
					_boundState = nil
				end
				function ctrl:Destroy()
					if destroyed then return end
					destroyed = true
					self:Unbind()
					changed:Destroy()
					Window:_unregisterControl(self)
					row:Destroy()
				end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Toggle")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── SLIDER ───────────────────────────────────────────────────────
			function Section:Slider(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Slider")
				Validation.warnUnknown(c2, { "Id", "Name", "Min", "Max", "Decimals", "Suffix", "Default", "Disabled", "Callback" }, "Slider")
				local sName   = c2.Name     or "Slider"
				local sMin    = c2.Min      or 0
				local sMax    = c2.Max      or 100
				local sDec    = c2.Decimals or 0
				local sSuffix = c2.Suffix   or ""
				if type(sMin) ~= "number" or type(sMax) ~= "number" or sMin >= sMax then
					error("EmberUI Slider requires numeric Min and Max where Min is less than Max", 2)
				end
				if type(sDec) ~= "number" or sDec < 0 or sDec % 1 ~= 0 or sDec > 6 then
					error("EmberUI Slider Decimals must be an integer from 0 to 6", 2)
				end
				if c2.Default ~= nil and type(c2.Default) ~= "number" then
					error("EmberUI Slider Default must be a number", 2)
				end
				local sDef    = math.clamp(c2.Default or sMin, sMin, sMax)
				local sCb     = c2.Callback

				local row = makeRow(sName, 54)
				rowNameLabel(row, sName)

				local valLbl = mkLabel({
					AnchorPoint    = Vector2.new(1, 0),
					Position       = UDim2.new(1, -14, 0, 7),
					Size           = UDim2.new(0, 96, 0, 20),
					TextSize       = 13,
					TextColor3     = T.Accent,
					TextXAlignment = Enum.TextXAlignment.Right,
					Font           = Enum.Font.GothamBold,
					ZIndex         = 6,
				}, row)

				local trackBg = Instance.new("Frame")
				trackBg.Position         = UDim2.new(0, 14, 0, 34)
				trackBg.Size             = UDim2.new(1, -28, 0, 5)
				trackBg.BackgroundColor3 = T.SurfaceHover
				trackBg.ZIndex           = 6
				trackBg.Parent           = row
				corner(trackBg, 3)

				local trackFill = Instance.new("Frame")
				trackFill.Size             = UDim2.new(0, 0, 1, 0)
				trackFill.BackgroundColor3 = T.Accent
				trackFill.ZIndex           = 7
				trackFill.Parent           = trackBg
				corner(trackFill, 3)
				grad(trackFill, T.AccentBright, T.AccentDark, 0)

				local handle = Instance.new("Frame")
				handle.Name              = "Handle"
				handle.AnchorPoint       = Vector2.new(0.5, 0.5)
				handle.Size              = UDim2.new(0, 13, 0, 13)
				handle.BackgroundColor3  = T.Text
				handle.ZIndex            = 9
				handle.Parent            = trackBg
				corner(handle, 7)
				stroke(handle, 2, T.AccentBright)

				local value = sDef
				local dragging = false
				local disabled = c2.Disabled == true
				local changed = Signal.new()
				if disabled then trackBg.BackgroundTransparency = 0.45 end

				local function updateVis(v)
					local pct = (v - sMin) / math.max(sMax - sMin, 1e-9)
					tw(trackFill, { Size = UDim2.new(pct, 0, 1, 0) }, TI_FAST)
					tw(handle, { Position = UDim2.new(pct, 0, 0.5, 0) }, TI_FAST)
					local fmt = sDec > 0
						and ("%." .. sDec .. "f%s"):format(v, sSuffix)
						or  ("%d%s"):format(math.floor(v + 0.5), sSuffix)
					valLbl.Text = fmt
				end

				updateVis(sDef)

				local hitArea = mkButton({
					Size     = UDim2.new(1, 0, 0, 20),
					Position = UDim2.new(0, 0, 0.5, -10),
					ZIndex   = 10,
				}, trackBg)
				hitArea.Active = not disabled

				local function setFromX(mx)
					local ap  = trackBg.AbsolutePosition
					local asX = trackBg.AbsoluteSize.X
					local pct = math.clamp((mx - ap.X) / math.max(asX, 1), 0, 1)
					local raw = sMin + pct * (sMax - sMin)
					local step = 1 / (10 ^ sDec)
					value = math.clamp(math.floor(raw / step + 0.5) * step, sMin, sMax)
					updateVis(value)
					callCallback("Slider", sCb, value)
					changed:Fire(value)
				end

				hitArea.InputBegan:Connect(function(inp)
					if not disabled and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
						dragging = true
						tw(handle, { Size = UDim2.new(0, 16, 0, 16) }, TI_FAST)
						setFromX(inp.Position.X)
					elseif not disabled and inp.UserInputType == Enum.UserInputType.Keyboard and (inp.KeyCode == Enum.KeyCode.Left or inp.KeyCode == Enum.KeyCode.Right) then
						local step = 1 / (10 ^ sDec)
						value = math.clamp(value + (inp.KeyCode == Enum.KeyCode.Right and step or -step), sMin, sMax)
						updateVis(value)
						callCallback("Slider", sCb, value)
						changed:Fire(value)
					end
				end)
				windowMaid:Give(UserInputService.InputChanged:Connect(function(inp)
					if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
						setFromX(inp.Position.X)
					end
				end))
				windowMaid:Give(UserInputService.InputEnded:Connect(function(inp)
					if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and dragging then
						dragging = false
						tw(handle, { Size = UDim2.new(0, 13, 0, 13) }, TI_FAST)
					end
				end))

				local ctrl = { _row = row, _name = sName }
				function ctrl:Set(v, fire)
					if type(v) ~= "number" then error("EmberUI Slider:Set expects a number", 2) end
					value = math.clamp(v, sMin, sMax)
					updateVis(value)
					if fire ~= false then
						callCallback("Slider", sCb, value)
						changed:Fire(value)
					end
				end
				function ctrl:Get() return value end
				function ctrl:Changed(callback) return changed:Connect(callback) end
				function ctrl:SetDisabled(nextDisabled)
					disabled = nextDisabled == true
					hitArea.Active = not disabled
					trackBg.BackgroundTransparency = disabled and 0.45 or 0
				end
				function ctrl:SetRange(mn, mx)
					if type(mn) ~= "number" or type(mx) ~= "number" or mn >= mx then
						error("EmberUI Slider:SetRange requires Min < Max", 2)
					end
					sMin = mn; sMax = mx
					value = math.clamp(value, sMin, sMax)
					updateVis(value)
				end
				local destroyed = false
				function ctrl:Destroy()
					if destroyed then return end
					destroyed = true
					changed:Destroy()
					Window:_unregisterControl(self)
					row:Destroy()
				end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Slider")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── DROPDOWN ─────────────────────────────────────────────────────
			function Section:Dropdown(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Dropdown")
				Validation.warnUnknown(c2, { "Id", "Name", "Options", "Multi", "Default", "Disabled", "Callback" }, "Dropdown")
				local dName    = c2.Name    or "Dropdown"
				local dOpts    = c2.Options or {}
				local dMulti   = c2.Multi   or false
				local dDefault = c2.Default
				local dCb      = c2.Callback
				if type(dOpts) ~= "table" then error("EmberUI Dropdown Options must be an array", 2) end
				local disabled = c2.Disabled == true
				local changed = Signal.new()

				local row = makeRow(dName, 42)
				rowNameLabel(row, dName)

				local DW = 168
				local ddBtn = mkButton({
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -12, 0.5, 0),
					Size             = UDim2.new(0, DW, 0, 27),
					BackgroundColor3 = T.SurfaceHi,
					BackgroundTransparency = 0,
					ZIndex           = 6,
				}, row)
				corner(ddBtn, 6)
				stroke(ddBtn, 1, T.Border)

				local ddValLbl = mkLabel({
					Position       = UDim2.new(0, 10, 0, 0),
					Size           = UDim2.new(1, -26, 1, 0),
					TextSize       = 12,
					TextColor3     = T.TextHint,
					Font           = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 7,
				}, ddBtn)

				local caret = mkLabel({
					AnchorPoint    = Vector2.new(1, 0.5),
					Position       = UDim2.new(1, -8, 0.5, 0),
					Size           = UDim2.new(0, 14, 0, 14),
					Text           = "▾",
					TextSize       = 11,
					TextColor3     = T.TextSub,
					ZIndex         = 7,
				}, ddBtn)

				local selected = {}
				if dDefault then
					if type(dDefault) == "table" then
						for _, v in ipairs(dDefault) do selected[v] = true end
					else
						selected[tostring(dDefault)] = true
					end
				end
				local function getValue()
					if dMulti then
						local values = {}
						for _, option in ipairs(dOpts) do if selected[option] then values[#values + 1] = option end end
						return values
					end
					for _, option in ipairs(dOpts) do if selected[option] then return option end end
					return nil
				end

				local function refreshLabel()
					local parts = {}
					for _, o in ipairs(dOpts) do
						if selected[o] then parts[#parts+1] = o end
					end
					if #parts == 0 then
						ddValLbl.Text = "None"; ddValLbl.TextColor3 = T.TextHint
					elseif #parts == 1 then
						ddValLbl.Text = parts[1]; ddValLbl.TextColor3 = T.Text
					else
						ddValLbl.Text = #parts .. " selected"; ddValLbl.TextColor3 = T.Text
					end
				end
				refreshLabel()

				local menuOpen = false
				local menuFrame = nil

				local function closeMenu()
					if menuFrame then
						overlayManager:Clear(menuFrame)
						menuFrame:Destroy()
						menuFrame = nil
					end
					menuOpen = false
					tw(caret, { Rotation = 0 })
				end

				local function openMenu()
					if menuOpen then closeMenu(); return end
					menuOpen = true
					tw(caret, { Rotation = 180 })

					local mH = math.min(#dOpts * 30 + 34, 214)
					local mf = Instance.new("ScrollingFrame")
					mf.Name                  = "DDMenu"
					mf.Size                  = UDim2.new(0, DW, 0, mH)
					mf.Position              = UDim2.new(
						0, ddBtn.AbsolutePosition.X - win.AbsolutePosition.X,
						0, ddBtn.AbsolutePosition.Y - win.AbsolutePosition.Y + ddBtn.AbsoluteSize.Y + 2
					)
					mf.BackgroundColor3      = T.SurfaceHi
					mf.BackgroundTransparency= 0
					mf.ScrollBarThickness    = 3
					mf.ScrollBarImageColor3  = T.Accent
					mf.CanvasSize            = UDim2.new(0, 0, 0, 0)
					mf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
					mf.ZIndex                = 30
					mf.Parent                = win
					corner(mf, 7)
					stroke(mf, 1, T.Border)
					list(mf, Enum.FillDirection.Vertical, 0)
					menuFrame = mf
					overlayManager:Open(mf, closeMenu)
					local searchWrap = mkFrame({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 0, BackgroundColor3 = T.Surface }, mf)
					local searchBox = Instance.new("TextBox")
					searchBox.Size = UDim2.new(1, -16, 1, -8)
					searchBox.Position = UDim2.new(0, 8, 0, 4)
					searchBox.BackgroundColor3 = T.SurfaceHover
					searchBox.TextColor3 = T.Text
					searchBox.PlaceholderColor3 = T.TextHint
					searchBox.PlaceholderText = "Search options..."
					searchBox.ClearTextOnFocus = false
					searchBox.Font = Enum.Font.Gotham
					searchBox.TextSize = 12
					searchBox.TextXAlignment = Enum.TextXAlignment.Left
					searchBox.ZIndex = 32
					searchBox.Parent = searchWrap
					corner(searchBox, 5)
					pad(searchBox, 8, 8, 0, 0)
					local optionRows = {}

					for _, opt in ipairs(dOpts) do
						local optRow = mkButton({
							LayoutOrder      = #optionRows + 1,
							Size             = UDim2.new(1, 0, 0, 30),
							BackgroundColor3 = T.SurfaceHover,
							BackgroundTransparency = selected[opt] and 0.5 or 1,
							ZIndex           = 31,
						}, mf)
						table.insert(optionRows, { option = opt, row = optRow })

						mkLabel({
							Position       = UDim2.new(0, 28, 0, 0),
							Size           = UDim2.new(1, -34, 1, 0),
							Text           = opt,
							TextSize       = 12,
							Font           = Enum.Font.Gotham,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex         = 32,
						}, optRow)

						local tick = mkLabel({
							Position       = UDim2.new(0, 8, 0, 0),
							Size           = UDim2.new(0, 18, 1, 0),
							Text           = selected[opt] and "✓" or "",
							TextSize       = 12,
							TextColor3     = T.On,
							ZIndex         = 32,
						}, optRow)

						optRow.MouseEnter:Connect(function()
							tw(optRow, { BackgroundTransparency = 0.4 })
						end)
						optRow.MouseLeave:Connect(function()
							tw(optRow, { BackgroundTransparency = selected[opt] and 0.5 or 1 })
						end)
						optRow.Activated:Connect(function()
							if not dMulti then
								for k in pairs(selected) do selected[k] = false end
							end
							selected[opt] = not selected[opt]
							tick.Text = selected[opt] and "✓" or ""
							refreshLabel()
							if dCb then
								if dMulti then
									local vals = {}
									for _, o in ipairs(dOpts) do
										if selected[o] then vals[#vals+1] = o end
									end
									callCallback("Dropdown", dCb, vals)
								else
									for _, o in ipairs(dOpts) do
									if selected[o] then callCallback("Dropdown", dCb, o); break end
									end
								end
							end
							changed:Fire(getValue())
							if not dMulti then closeMenu() end
						end)
					end
					searchBox:GetPropertyChangedSignal("Text"):Connect(function()
						local query = searchBox.Text:lower()
						for _, entry in ipairs(optionRows) do
							entry.row.Visible = query == "" or entry.option:lower():find(query, 1, true) ~= nil
						end
					end)
				end

				ddBtn.Active = not disabled
				if disabled then ddBtn.BackgroundTransparency = 0.45 end
				ddBtn.Activated:Connect(function()
					if not disabled then openMenu() end
				end)
				local ctrl = { _row = row, _name = dName }
				function ctrl:Get() return getValue() end
				function ctrl:Changed(callback) return changed:Connect(callback) end
				function ctrl:Set(v, fire)
					for k in pairs(selected) do selected[k] = false end
					if type(v) == "table" then
						for _, val in ipairs(v) do selected[val] = true end
					elseif v then selected[tostring(v)] = true end
					refreshLabel()
					if fire ~= false then
						callCallback("Dropdown", dCb, getValue())
						changed:Fire(getValue())
					end
				end
				function ctrl:SetDisabled(nextDisabled)
					disabled = nextDisabled == true
					ddBtn.Active = not disabled
					ddBtn.BackgroundTransparency = disabled and 0.45 or 0
					if disabled then closeMenu() end
				end
				function ctrl:SetOptions(opts)
					dOpts = opts
					for k in pairs(selected) do
						local found = false
						for _, o in ipairs(opts) do if o == k then found = true; break end end
						if not found then selected[k] = nil end
					end
					refreshLabel()
				end
				function ctrl:Destroy() changed:Destroy(); closeMenu(); Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Dropdown")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── BUTTON ───────────────────────────────────────────────────────
			function Section:Button(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Button")
				Validation.warnUnknown(c2, { "Id", "Name", "Text", "Disabled", "Callback" }, "Button")
				local bName = c2.Name or "Button"
				local bText = c2.Text or bName
				local bCb   = c2.Callback
				local disabled = c2.Disabled == true

				local row = makeRow(bName, 42)
				rowNameLabel(row, bName)

				local btn = mkButton({
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -12, 0.5, 0),
					Size             = UDim2.new(0, 104, 0, 26),
					BackgroundColor3 = T.Accent,
					BackgroundTransparency = 0,
					Text             = bText,
					TextSize         = 12,
					Font             = Enum.Font.GothamBold,
					TextColor3       = T.Text,
					ZIndex           = 6,
				}, row)
				corner(btn, 6)
				stroke(btn, 1, T.AccentDark)
				grad(btn, T.AccentBright, T.AccentDark, 90)
				btn.Active = not disabled
				if disabled then btn.BackgroundTransparency = 0.45 end

				btn.MouseEnter:Connect(function() tw(btn, { BackgroundColor3 = T.AccentBright }) end)
				btn.MouseLeave:Connect(function() tw(btn, { BackgroundColor3 = T.Accent }) end)
				btn.Activated:Connect(function()
					if disabled then return end
					tw(btn, { BackgroundColor3 = T.AccentDark })
					task.delay(0.08, function() tw(btn, { BackgroundColor3 = T.Accent }) end)
					callCallback("Button", bCb)
				end)

				local ctrl = { _row = row, _name = bName }
				function ctrl:Press() if not disabled then callCallback("Button", bCb) end end
				function ctrl:SetText(t) btn.Text = t end
				function ctrl:SetDisabled(nextDisabled)
					disabled = nextDisabled == true
					btn.Active = not disabled
					btn.BackgroundTransparency = disabled and 0.45 or 0
				end
				function ctrl:Destroy() Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Button")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── INPUT ────────────────────────────────────────────────────────
			function Section:Input(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Input")
				Validation.warnUnknown(c2, { "Id", "Name", "Placeholder", "Default", "Numeric", "Disabled", "Callback" }, "Input")
				local iName = c2.Name        or "Input"
				local iPlc  = c2.Placeholder or ""
				local iDef  = c2.Default     or ""
				local iCb   = c2.Callback
				local iNum  = c2.Numeric     or false
				local disabled = c2.Disabled == true
				local changed = Signal.new()

				local row = makeRow(iName, 42)
				rowNameLabel(row, iName)

				local wrap = Instance.new("Frame")
				wrap.AnchorPoint            = Vector2.new(1, 0.5)
				wrap.Position               = UDim2.new(1, -12, 0.5, 0)
				wrap.Size                   = UDim2.new(0, 158, 0, 26)
				wrap.BackgroundColor3       = T.SurfaceHover
				wrap.BackgroundTransparency = 0
				wrap.ZIndex                 = 6
				wrap.Parent                 = row
				corner(wrap, 6)
				stroke(wrap, 1, T.Border)

				local tb = Instance.new("TextBox")
				tb.Size              = UDim2.new(1, -16, 1, 0)
				tb.Position          = UDim2.new(0, 8, 0, 0)
				tb.BackgroundTransparency = 1
				tb.Text              = iDef
				tb.PlaceholderText   = iPlc
				tb.PlaceholderColor3 = T.TextHint
				tb.TextColor3        = T.Text
				tb.Font              = Enum.Font.Gotham
				tb.TextSize          = 12
				tb.TextXAlignment    = Enum.TextXAlignment.Left
				tb.ClearTextOnFocus  = false
				tb.ZIndex            = 7
				tb.Parent            = wrap

				tb.Focused:Connect(function() stroke(wrap, 1, T.Accent) end)
				tb.FocusLost:Connect(function(enter)
					stroke(wrap, 1, T.Border)
					if enter then
						local v = tb.Text
						if iNum then v = tostring(tonumber(v) or 0); tb.Text = v end
						callCallback("Input", iCb, v)
						changed:Fire(v)
					end
				end)
				tb.TextEditable = not disabled
				if disabled then wrap.BackgroundTransparency = 0.45 end

				local ctrl = { _row = row, _name = iName }
				function ctrl:Get() return tb.Text end
				function ctrl:Changed(callback) return changed:Connect(callback) end
				function ctrl:Set(v, fire)
					tb.Text = tostring(v)
					if fire ~= false then callCallback("Input", iCb, tb.Text); changed:Fire(tb.Text) end
				end
				function ctrl:SetDisabled(nextDisabled)
					disabled = nextDisabled == true
					tb.TextEditable = not disabled
					wrap.BackgroundTransparency = disabled and 0.45 or 0
				end
				function ctrl:Destroy() changed:Destroy(); Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Input")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── LABEL ────────────────────────────────────────────────────────
			function Section:Label(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Label")
				local text = c2.Text or ""

				local row = makeRow("_lbl", 34)
				local lbl = mkLabel({
					Position       = UDim2.new(0, 14, 0, 0),
					Size           = UDim2.new(1, -28, 1, 0),
					Text           = text,
					TextSize       = 12,
					TextColor3     = T.TextSub,
					Font           = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 6,
				}, row)

				local ctrl = { _row = row, _name = text }
				function ctrl:Set(v) lbl.Text = v end
				function ctrl:Get() return lbl.Text end
				function ctrl:Destroy() Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Label")
				return ctrl
			end

			-- ── KEYBIND ──────────────────────────────────────────────────────
			function Section:Keybind(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "Keybind")
				Validation.warnUnknown(c2, { "Id", "Name", "Default", "Disabled", "Callback" }, "Keybind")
				local kName = c2.Name    or "Keybind"
				local kDef  = c2.Default or Enum.KeyCode.Unknown
				local kCb   = c2.Callback

				local row = makeRow(kName, 42)
				rowNameLabel(row, kName)

				local kBtn = mkButton({
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -12, 0.5, 0),
					Size             = UDim2.new(0, 90, 0, 26),
					BackgroundColor3 = T.SurfaceHover,
					BackgroundTransparency = 0,
					ZIndex           = 6,
				}, row)
				corner(kBtn, 6)
				stroke(kBtn, 1, T.Border)

				local kLbl = mkLabel({
					Size           = UDim2.new(1, 0, 1, 0),
					TextSize       = 12,
					TextColor3     = T.Text,
					Font           = Enum.Font.GothamBold,
					ZIndex         = 7,
				}, kBtn)

				local currentKey = kDef
				local listening  = false
				local listenConn = nil
				local disabled = c2.Disabled == true
				local changed = Signal.new()

				local function setKey(k, fire)
					currentKey = k
					kLbl.Text      = k.Name
					kLbl.TextColor3= T.Text
					tw(kBtn, { BackgroundColor3 = T.SurfaceHi })
					stroke(kBtn, 1, T.Border)
					if fire ~= false then
						callCallback("Keybind", kCb, k)
						changed:Fire(k)
					end
				end

				setKey(kDef, false)
				kBtn.Active = not disabled
				if disabled then kBtn.BackgroundTransparency = 0.45 end

				kBtn.Activated:Connect(function()
					if disabled then return end
					if listening then
						listening = false
						if listenConn then listenConn:Disconnect(); listenConn = nil end
						setKey(currentKey, false)
						return
					end
					listening       = true
					kLbl.Text       = "..."
					kLbl.TextColor3 = T.TextSub
					tw(kBtn, { BackgroundColor3 = T.SurfaceHover })
					stroke(kBtn, 1, T.Accent)

					listenConn = windowMaid:Give(UserInputService.InputBegan:Connect(function(inp)
						if not listening then return end
						if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
						listening = false
						if listenConn then listenConn:Disconnect(); listenConn = nil end
						if inp.KeyCode == Enum.KeyCode.Escape then
							setKey(currentKey, false)
						else
							setKey(inp.KeyCode)
						end
					end))
				end)

				kBtn.MouseEnter:Connect(function()
					if not listening then tw(kBtn, { BackgroundColor3 = T.BorderHi }) end
				end)
				kBtn.MouseLeave:Connect(function()
					if not listening then tw(kBtn, { BackgroundColor3 = T.SurfaceHover }) end
				end)

				local ctrl = { _row = row, _name = kName }
				function ctrl:Get() return currentKey end
				function ctrl:Set(k) setKey(k) end
				function ctrl:Changed(callback) return changed:Connect(callback) end
				function ctrl:SetDisabled(nextDisabled)
					disabled = nextDisabled == true
					kBtn.Active = not disabled
					kBtn.BackgroundTransparency = disabled and 0.45 or 0
					if disabled and listening then
						listening = false
						if listenConn then listenConn:Disconnect(); listenConn = nil end
						setKey(currentKey, false)
					end
				end
				function ctrl:Destroy()
					if listenConn then listenConn:Disconnect(); listenConn = nil end
					changed:Destroy()
					Window:_unregisterControl(self)
					row:Destroy()
				end
				function ctrl:SetVisible(v) row.Visible = v end

					Window:_registerControl(ctrl, c2, "Keybind")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			return Section
		end

		return Tab
	end

	-- ── Search ───────────────────────────────────────────────────────────────
	local function applySearch(query)
		query = query:lower()
		for _, el in ipairs(Window._allElements) do
			if el._row and el._name then
				el._row.Visible = query == "" or el._name:lower():find(query, 1, true) ~= nil
			end
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		applySearch(searchBox.Text)
	end)

	function Window:Search(q) searchBox.Text = q; applySearch(q) end

	return Window
end

-- ── Public API ────────────────────────────────────────────────────────────────
local EmberUI = {}
function EmberUI:Window(cfg)
	cfg = cfg or {}
	if type(cfg) ~= "table" then error("EmberUI:Window expects a configuration table", 2) end
	if cfg.Id and cfg.Singleton ~= false then
		local existing: any = windowManager:Get(cfg.Id)
		if existing then
			existing:SetVisible(true)
			existing:BringToFront()
			return existing
		end
	end
	local window = buildWindow(cfg)
	windowManager:Register(cfg.Id, window)
	return window
end
EmberUI.State = State
EmberUI.Version = require(Root.Version)
EmberUI.PersistenceManager = PersistenceManager
function EmberUI:SetTheme(name) themeManager:SetTheme(name) end
function EmberUI:GetTheme() return themeManager:GetName() end
function EmberUI:SetReducedMotion(enabled) reducedMotion = enabled == true end
function EmberUI:GetReducedMotion() return reducedMotion end

return EmberUI
