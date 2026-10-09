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
local VirtualList = require(Root.Layout.VirtualList)
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
local function corner(p, _r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 0)
	c.Parent = p
	return c
end

-- Removes any existing UIStroke before adding a new one (prevents accumulation)
local function stroke(p, thick, col, trans)
	local e = p:FindFirstChildOfClass("UIStroke")
	if e then e:Destroy() end
	local s = Instance.new("UIStroke")
	s.Thickness       = thick or 2
	s.Color           = col   or T.Border
	s.Transparency    = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

-- Removes any existing UIGradient before adding a new one
local function textStroke(p)
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Parent = p
	return s
end

local function grad(p, c0, c1, rot)
	local e = p:FindFirstChildOfClass("UIGradient")
	if e then e:Destroy() end
	local g = Instance.new("UIGradient")
	g.Color    = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent   = p
	return g
end

local function redGrad(p)
	p.BackgroundColor3 = T.Accent
	local existing = p:FindFirstChild("_rg")
	if existing then existing:Destroy() end
	local ov = Instance.new("Frame")
	ov.Name                   = "_rg"
	ov.Size                   = UDim2.new(1, 0, 1, 0)
	ov.BackgroundColor3       = Color3.new(1, 1, 1)
	ov.BackgroundTransparency = 0
	ov.ZIndex                 = p.ZIndex + 1
	ov.Parent                 = p
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0))
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.60),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1,   0.65),
	})
	g.Rotation = 90
	g.Parent   = ov
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
	l.Font       = Enum.Font.Gotham
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
	b.Font            = Enum.Font.Gotham
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
	local dragging = false
	local lastMouse = nil
	maid:Give(handle.InputBegan:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1
			and inp.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging   = true
		lastMouse  = UserInputService:GetMouseLocation()
	end))
	maid:Give(UserInputService.InputChanged:Connect(function(inp)
		if not dragging or not lastMouse then return end
		if inp.UserInputType ~= Enum.UserInputType.MouseMovement
			and inp.UserInputType ~= Enum.UserInputType.Touch then return end
		local mouse = UserInputService:GetMouseLocation()
		local delta = mouse - lastMouse
		lastMouse   = mouse
		target.Position = UDim2.new(
			target.Position.X.Scale, target.Position.X.Offset + delta.X,
			target.Position.Y.Scale, target.Position.Y.Offset + delta.Y
		)
		if onMove then onMove() end
	end))
	maid:Give(UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging  = false
			lastMouse = nil
		end
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
	Validation.warnUnknown(cfg, { "Id", "Title", "Width", "Height", "Scale", "Singleton" }, "Window")
	cfg.Title   = cfg.Title  or "EmberUI"
	cfg.Width   = cfg.Width  or 460
	cfg.Height  = cfg.Height or 360
	if type(cfg.Title) ~= "string" then error("EmberUI:Window Title must be a string", 2) end
	if type(cfg.Width) ~= "number" or cfg.Width <= 0 then error("EmberUI:Window Width must be a positive number", 2) end
	if type(cfg.Height) ~= "number" or cfg.Height <= 0 then error("EmberUI:Window Height must be a positive number", 2) end
	if cfg.Scale ~= nil and (type(cfg.Scale) ~= "number" or cfg.Scale < 0.75 or cfg.Scale > 1.5) then error("EmberUI:Window Scale must be between 0.75 and 1.5", 2) end
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

	local TOPBAR_H  = 40
	local SEARCH_H  = 34
	local SIDEBAR_W = 158
	local SIDEBAR_GAP = -4

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
	win.BackgroundTransparency= 0.40
	win.ClipsDescendants      = false
	win.Parent                = gui
	corner(win, 3)
	stroke(win, 2, T.Border)
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
	task.defer(clampToViewport)
	if workspace.CurrentCamera then
		windowMaid:Give(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(clampToViewport))
	end

	-- ── TopBar ────────────────────────────────────────────────────────────────
	local topBar = Instance.new("Frame")
	topBar.Name             = "TopBar"
	topBar.Size             = UDim2.new(1, 0, 0, TOPBAR_H)
	topBar.BackgroundColor3 = Color3.new(1, 1, 1)
	topBar.ZIndex           = 6
	topBar.Parent           = win
	corner(topBar, 3)
	stroke(topBar, 2, T.Border)
	redGrad(topBar)

	local titleLbl = mkLabel({
		Position       = UDim2.new(0, 12, 0, 0),
		Size           = UDim2.new(1, -80, 1, 0),
		Text           = cfg.Title,
		Font           = Enum.Font.GothamBlack,
		TextSize       = 20,
		TextColor3     = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex         = 7,
	}, topBar)
	textStroke(titleLbl)

	local minimizeBtn = mkButton({
		Size             = UDim2.new(0, 28, 0, 28),
		Position         = UDim2.new(1, -64, 0.5, 0),
		AnchorPoint      = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text             = "—",
		TextSize         = 16,
		Font             = Enum.Font.GothamBlack,
		TextColor3       = T.Text,
		ZIndex           = 8,
	}, topBar)
	minimizeBtn.MouseEnter:Connect(function() tw(minimizeBtn, { TextColor3 = T.TextSub }) end)
	minimizeBtn.MouseLeave:Connect(function() tw(minimizeBtn, { TextColor3 = T.Text }) end)

	local closeBtn = mkButton({
		Size             = UDim2.new(0, 28, 0, 28),
		Position         = UDim2.new(1, -32, 0.5, 0),
		AnchorPoint      = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text             = "✕",
		TextSize         = 14,
		Font             = Enum.Font.GothamBlack,
		TextColor3       = T.Text,
		ZIndex           = 8,
	}, topBar)
	closeBtn.MouseEnter:Connect(function() tw(closeBtn, { TextColor3 = T.TextSub }) end)
	closeBtn.MouseLeave:Connect(function() tw(closeBtn, { TextColor3 = T.Text }) end)
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
	leftSide.Position               = UDim2.new(0, -SIDEBAR_GAP - 10, 0, TOPBAR_H)
	leftSide.Size                   = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H)
	leftSide.BackgroundColor3       = T.Bg
	leftSide.BackgroundTransparency = 1
	leftSide.ScrollBarThickness     = 0
	leftSide.CanvasSize             = UDim2.new(0, 0, 0, 0)
	leftSide.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	leftSide.ClipsDescendants       = false
	leftSide.ZIndex                 = 3
	leftSide.Parent                 = win
	list(leftSide, Enum.FillDirection.Vertical, 8)

	-- ── Right sidebar ────────────────────────────────────────────────────────
	local rightSide = Instance.new("Frame")
	rightSide.Name                   = "RightSidebar"
	rightSide.Position               = UDim2.new(1, SIDEBAR_GAP + 10, 0, TOPBAR_H)
	rightSide.Size                   = UDim2.new(0, SIDEBAR_W, 0, 0)
	rightSide.AutomaticSize          = Enum.AutomaticSize.Y
	rightSide.BackgroundColor3       = T.Bg
	rightSide.BackgroundTransparency = 1
	rightSide.ClipsDescendants       = false
	rightSide.ZIndex                 = 3
	rightSide.Parent                 = win
	list(rightSide, Enum.FillDirection.Vertical, 8)

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
	searchBar.BackgroundColor3      = T.Surface
	searchBar.BackgroundTransparency= 0
	searchBar.ZIndex                = 6
	searchBar.Parent                = win
	corner(searchBar, 3)
	fixCorners(searchBar, "top", T.Surface)
	stroke(searchBar, 2, T.Border)

	mkLabel({
		Position       = UDim2.new(0, 12, 0, 0),
		Size           = UDim2.new(0, 52, 1, 0),
		Text           = "Search",
		TextSize       = 14,
		Font           = Enum.Font.GothamBold,
		TextColor3     = T.TextSub,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex         = 7,
	}, searchBar)

	mkFrame({
		Size             = UDim2.new(0, 1, 0.6, 0),
		Position         = UDim2.new(0, 68, 0.2, 0),
		BackgroundColor3 = T.BorderHi,
		BackgroundTransparency = 0,
		ZIndex           = 7,
	}, searchBar)

	local searchBox = Instance.new("TextBox")
	searchBox.Text              = ""
	searchBox.Size              = UDim2.new(1, -80, 1, -8)
	searchBox.Position          = UDim2.new(0, 74, 0, 4)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText   = "Filter features..."
	searchBox.PlaceholderColor3 = T.TextHint
	searchBox.TextColor3        = T.Text
	searchBox.Font              = Enum.Font.Gotham
	searchBox.TextSize          = 14
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
	Window._sections    = {}
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
			Size             = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ZIndex           = 4,
		}, rightSide)
		corner(btn, 0)
		redGrad(btn)
		stroke(btn, 2, T.Border)
		local lbl = mkLabel({ Size = UDim2.new(1, 0, 1, 0), Text = name2, TextSize = 14, Font = Enum.Font.GothamBlack, ZIndex = 5, TextColor3 = T.Text }, btn)
		textStroke(lbl)
		btn.MouseEnter:Connect(function() redGrad(btn) end)
		btn.MouseLeave:Connect(function() redGrad(btn) end)
		btn.Activated:Connect(function() callCallback("SideButton", callback) end)
		return btn
	end

	-- ── Tab ──────────────────────────────────────────────────────────────────
	function Window:Tab(name2)
		local Tab = { _btn = nil, _page = nil, _win = Window }

		local tabBtn = mkButton({
			Name             = name2,
			Size             = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ZIndex           = 4,
		}, leftSide)
		corner(tabBtn, 0)
		stroke(tabBtn, 2, T.Border)
		redGrad(tabBtn)
		Tab._btn = tabBtn

		local lbl = mkLabel({
			Size           = UDim2.new(1, 0, 1, 0),
			Text           = name2,
			TextSize       = 14,
			Font           = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3     = T.Text,
			ZIndex         = 5,
		}, tabBtn)
		textStroke(lbl)

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
		pad(page, 6, 8, 6, 6)
		list(page, Enum.FillDirection.Vertical, 4)
		Tab._page = page

		local function activate()
			if Window._activeTab == Tab then return end
			if Window._activeTab then
				local old = Window._activeTab
				old._page.Visible = false
				redGrad(old._btn)
				stroke(old._btn, 2, T.Border)
			end
			page.Visible = true
			redGrad(tabBtn)
			stroke(tabBtn, 2, T.Border)
			Window._activeTab = Tab
		end

		tabBtn.Activated:Connect(activate)
		tabBtn.MouseEnter:Connect(function() redGrad(tabBtn) end)
		tabBtn.MouseLeave:Connect(function() redGrad(tabBtn) end)

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
			secWrap.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
			secWrap.BackgroundTransparency= 0.70
			secWrap.ZIndex                = 4
			secWrap.Parent                = page
			corner(secWrap, 3)
			stroke(secWrap, 2, T.Border)
			list(secWrap, Enum.FillDirection.Vertical, 0)

			local hdr = Instance.new("Frame")
			hdr.Name             = "Header"
			hdr.LayoutOrder      = 0
			hdr.Size             = UDim2.new(1, 0, 0, 32)
			hdr.BackgroundTransparency = 1
			hdr.ZIndex           = 5
			hdr.Parent           = secWrap

			mkFrame({
				AnchorPoint      = Vector2.new(0, 1),
				Position         = UDim2.new(0, 0, 1, 0),
				Size             = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = T.Border,
				BackgroundTransparency = 0,
				ZIndex           = 6,
			}, hdr)

			local chevLbl = mkLabel({
				Position       = UDim2.new(0, 8, 0, 0),
				Size           = UDim2.new(0, 18, 1, 0),
				Text           = expanded and "v" or ">",
				TextSize       = 14,
				TextColor3     = T.Text,
				Font           = Enum.Font.GothamBlack,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex         = 6,
			}, hdr)
			textStroke(chevLbl)

			local lbl = mkLabel({
				Position       = UDim2.new(0, 28, 0, 0),
				Size           = UDim2.new(1, -34, 1, 0),
				Text           = sname,
				TextSize       = 14,
				TextColor3     = T.Text,
				Font           = Enum.Font.GothamBlack,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex         = 6,
			}, hdr)
			textStroke(lbl)

			local hdrHit = mkButton({ Size = UDim2.new(1, 0, 1, 0), ZIndex = 7 }, hdr)

			local contentFrame = mkFrame({
				Name          = "Content",
				LayoutOrder   = 1,
				Size          = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible       = expanded,
				ZIndex        = 4,
			}, secWrap)
			pad(contentFrame, 6, 6, 4, 4)
			list(contentFrame, Enum.FillDirection.Vertical, 4)

			hdrHit.Activated:Connect(function()
				contentFrame.Visible = not contentFrame.Visible
				chevLbl.Text = contentFrame.Visible and "v" or ">"
			end)

			-- ── Section object ────────────────────────────────────────────────
			local Section = { _content = contentFrame, _elements = {}, _wrap = secWrap }
			table.insert(Window._sections, Section)

			local function makeRow(rname, h)
				local row = Instance.new("Frame")
				row.Name                  = rname
				row.Size                  = UDim2.new(1, 0, 0, h)
				row.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
				row.BackgroundTransparency= 0.60
				row.ZIndex                = 5
				row.Parent                = contentFrame
				stroke(row, 1, T.Border)
				return row
			end

			local function rowNameLabel(row, text, xOff)
				local lbl = mkLabel({
					Position       = UDim2.new(0, xOff or 12, 0, 0),
					Size           = UDim2.new(0.55, 0, 1, 0),
					Text           = text,
					TextSize       = 14,
					TextColor3     = T.Text,
					Font           = Enum.Font.GothamBlack,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 6,
				}, row)
				textStroke(lbl)
				return lbl
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
				local row = makeRow(c2.Name or "Progress", 40)
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

				local ROW_H = hasNote and 54 or 40
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

				local TRACK_W = 42
				local TRACK_H = 22
				local KNOB_S  = 16

				local track = Instance.new("Frame")
				track.AnchorPoint      = Vector2.new(1, 0.5)
				track.Position         = UDim2.new(1, -12, 0.5, 0)
				track.Size             = UDim2.new(0, TRACK_W, 0, TRACK_H)
				track.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
				track.ZIndex           = 7
				track.Parent           = row
				stroke(track, 1, T.Border)

				local knob = Instance.new("Frame")
				knob.AnchorPoint      = Vector2.new(0, 0.5)
				knob.Position         = UDim2.new(0, 3, 0.5, 0)
				knob.Size             = UDim2.new(0, KNOB_S, 0, KNOB_S)
				knob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
				knob.ZIndex           = 8
				knob.Parent           = track

				local hit = mkButton({ Size = UDim2.new(1, 0, 1, 0), ZIndex = 9 }, row)

				local value = tDef
				local _boundState = nil
				local _unsubscribe = nil
				local destroyed = false
				local disabled = c2.Disabled == true
				local changed = Signal.new()

				local onPos  = UDim2.new(0, TRACK_W - KNOB_S - 3, 0.5, 0)
				local offPos = UDim2.new(0, 3, 0.5, 0)

				local function applyToggle(v, fire)
					value = v
					if v then
						local e = track:FindFirstChildOfClass("UIGradient")
						if e then e:Destroy() end
						track.BackgroundColor3 = Color3.new(1, 1, 1)
						local g = Instance.new("UIGradient")
						g.Color = ColorSequence.new(Color3.fromRGB(58, 255, 55), Color3.fromRGB(20, 109, 0))
						g.Rotation = 90
						g.Parent = track
						tw(knob, { Position = onPos, BackgroundColor3 = Color3.fromRGB(255, 255, 255) }, TI_FAST)
					else
						local e = track:FindFirstChildOfClass("UIGradient")
						if e then e:Destroy() end
						track.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
						tw(knob, { Position = offPos, BackgroundColor3 = Color3.fromRGB(120, 120, 120) }, TI_FAST)
					end
					if fire ~= false then
						callCallback("Toggle", tCb, v)
						changed:Fire(v)
					end
					if _boundState then _boundState:Set(v) end
				end

				applyToggle(tDef, false)
				hit.Active = not disabled
				if disabled then track.BackgroundTransparency = 0.45 end
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
					track.BackgroundTransparency = disabled and 0.45 or 0
				end
				function ctrl:SetNote(txt)
					dynNote.Text    = txt
					dynNote.Visible = txt ~= ""
					row.Size = UDim2.new(1, 0, 0, txt ~= "" and 54 or 40)
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

				local row = makeRow(sName, 44)

				local nameLbl = mkLabel({
					Position       = UDim2.new(0, 12, 0, 0),
					Size           = UDim2.new(0.42, 0, 1, 0),
					Text           = sName,
					TextSize       = 14,
					TextColor3     = T.Text,
					Font           = Enum.Font.GothamBlack,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 6,
				}, row)
				textStroke(nameLbl)

				local valLbl = mkLabel({
					AnchorPoint    = Vector2.new(1, 0.5),
					Position       = UDim2.new(1, -12, 0.5, 0),
					Size           = UDim2.new(0, 52, 0, 20),
					TextSize       = 12,
					TextColor3     = T.TextSub,
					TextXAlignment = Enum.TextXAlignment.Right,
					Font           = Enum.Font.GothamBold,
					ZIndex         = 6,
				}, row)

				local trackBg = Instance.new("Frame")
				trackBg.AnchorPoint      = Vector2.new(0, 0.5)
				trackBg.Position         = UDim2.new(0.44, 0, 0.5, 0)
				trackBg.Size             = UDim2.new(0.56, -72, 0, 6)
				trackBg.BackgroundColor3 = T.SurfaceHover
				trackBg.ZIndex           = 6
				trackBg.Parent           = row
				corner(trackBg, 0)

				local trackFill = Instance.new("Frame")
				trackFill.Size             = UDim2.new(0, 0, 1, 0)
				trackFill.BackgroundColor3 = Color3.new(1, 1, 1)
				trackFill.ZIndex           = 7
				trackFill.Parent           = trackBg
				corner(trackFill, 0)
				redGrad(trackFill)

				local handle = Instance.new("Frame")
				handle.Name              = "Handle"
				handle.AnchorPoint       = Vector2.new(0.5, 0.5)
				handle.Size              = UDim2.new(0, 14, 0, 14)
				handle.BackgroundColor3  = T.AccentBright
				handle.ZIndex            = 9
				handle.Parent            = trackBg
				corner(handle, 0)

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
						tw(handle, { Size = UDim2.new(0, 17, 0, 17), BackgroundColor3 = Color3.fromRGB(255, 193, 194) }, TI_FAST)
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
						tw(handle, { Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = T.AccentBright }, TI_FAST)
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

				local row = makeRow(dName, 40)
				rowNameLabel(row, dName)

				local DW = 176
				local ddBtn = mkButton({
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -10, 0.5, 0),
					Size             = UDim2.new(0, DW, 0, 26),
					BackgroundColor3 = T.SurfaceHi,
					BackgroundTransparency = 0,
					ZIndex           = 6,
				}, row)
				corner(ddBtn, 2)
				stroke(ddBtn, 1, T.Border)

				local ddValLbl = mkLabel({
					Position       = UDim2.new(0, 8, 0, 0),
					Size           = UDim2.new(1, -28, 1, 0),
					TextSize       = 13,
					TextColor3     = T.TextSub,
					Font           = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 7,
				}, ddBtn)

				local caretWrap = Instance.new("Frame")
				caretWrap.AnchorPoint           = Vector2.new(1, 0.5)
				caretWrap.Position              = UDim2.new(1, -8, 0.5, 0)
				caretWrap.Size                  = UDim2.new(0, 14, 0, 10)
				caretWrap.BackgroundTransparency= 1
				caretWrap.ZIndex                = 7
				caretWrap.Parent                = ddBtn
				local caretA = Instance.new("Frame")
				caretA.Size            = UDim2.new(0, 9, 0, 2)
				caretA.AnchorPoint     = Vector2.new(0.5, 0.5)
				caretA.Position        = UDim2.new(0.5, -3, 0.5, 0)
				caretA.Rotation        = 45
				caretA.BackgroundColor3= Color3.fromRGB(58, 255, 55)
				caretA.BorderSizePixel = 0
				caretA.ZIndex          = 7
				caretA.Parent          = caretWrap
				local caretB = Instance.new("Frame")
				caretB.Size            = UDim2.new(0, 9, 0, 2)
				caretB.AnchorPoint     = Vector2.new(0.5, 0.5)
				caretB.Position        = UDim2.new(0.5, 3, 0.5, 0)
				caretB.Rotation        = -45
				caretB.BackgroundColor3= Color3.fromRGB(58, 255, 55)
				caretB.BorderSizePixel = 0
				caretB.ZIndex          = 7
				caretB.Parent          = caretWrap

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
						ddValLbl.Text = parts[1]; ddValLbl.TextColor3 = T.TextSub
					else
						ddValLbl.Text = #parts .. " selected"; ddValLbl.TextColor3 = T.TextSub
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
					tw(caretWrap, { Rotation = 0 }, TI_FAST)
				end

				local function openMenu()
																				if menuOpen then closeMenu(); return end
																				menuOpen = true
																				tw(caretWrap, { Rotation = 180 }, TI_FAST)

																				local mH = 214
																				local menuContainer = Instance.new("Frame")
																				menuContainer.Name = "DDMenuContainer"
																				menuContainer.Size = UDim2.new(0, DW, 0, mH)
																				menuContainer.Position = UDim2.new(
																								0, ddBtn.AbsolutePosition.X - win.AbsolutePosition.X,
																								0, ddBtn.AbsolutePosition.Y - win.AbsolutePosition.Y + ddBtn.AbsoluteSize.Y + 2
																				)
																				menuContainer.BackgroundColor3 = T.SurfaceHi
																				menuContainer.BackgroundTransparency = 0
																				menuContainer.ZIndex = 30
																				menuContainer.Parent = win
																				corner(menuContainer, 7)
																				stroke(menuContainer, 1, T.Border)
																				menuFrame = menuContainer
																				overlayManager:Open(menuContainer, closeMenu)

																				local searchWrap = mkFrame({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = T.Surface }, menuContainer)
																				corner(searchWrap, 7)
																				-- Fix bottom corners of searchWrap so it blends with the container
																				fixCorners(searchWrap, "bottom", T.Surface, 7)
																				
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
																				
																				-- Separator line
																				mkFrame({
																								AnchorPoint = Vector2.new(0, 1),
																								Position = UDim2.new(0, 0, 1, 0),
																								Size = UDim2.new(1, 0, 0, 1),
																								BackgroundColor3 = T.Border,
																								BackgroundTransparency = 0.5,
																								ZIndex = 33
																				}, searchWrap)

																				local mf = Instance.new("ScrollingFrame")
																				mf.Name = "DDMenuScroll"
																				mf.Size = UDim2.new(1, 0, 1, -34)
																				mf.Position = UDim2.new(0, 0, 0, 34)
																				mf.BackgroundTransparency = 1
																				mf.ScrollBarThickness = 3
																				mf.ScrollBarImageColor3 = T.Accent
																				mf.CanvasSize = UDim2.new(0, 0, 0, 0)
																				mf.AutomaticCanvasSize = Enum.AutomaticSize.None
																				mf.ZIndex = 31
																				mf.Parent = menuContainer

																				local virtualList = VirtualList.new(30, 2)
																				local filteredOpts = {}
																				for _, o in ipairs(dOpts) do table.insert(filteredOpts, o) end

																				local pool = {}
																				local function updateList()
																								local contentHeight = virtualList:GetCanvasHeight(#filteredOpts)
																								mf.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
																								local listH = math.min(#filteredOpts * 30, 214 - 34)
																								menuContainer.Size = UDim2.new(0, DW, 0, listH + 34)

																								local first, last = virtualList:GetRange(#filteredOpts, mf.CanvasPosition.Y, listH)
																								local activeCount = 0

																								for i = first, last do
																												activeCount = activeCount + 1
																												local opt = filteredOpts[i]
																												local row = pool[activeCount]
																												if not row then
																																row = mkButton({ Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.SurfaceHover, BackgroundTransparency = 0.2, ZIndex = 31 }, mf)
																																stroke(row, 1, T.Border)
																																local lbl = mkLabel({ Position = UDim2.new(0, 28, 0, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }, row)
																																local tick = mkLabel({ Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0, 18, 1, 0), TextSize = 12, TextColor3 = T.On, Font = Enum.Font.GothamBlack, ZIndex = 32 }, row)

																																row.MouseEnter:Connect(function() tw(row, { BackgroundTransparency = 0 }) end)
																																row.MouseLeave:Connect(function() tw(row, { BackgroundTransparency = selected[row._opt] and 0 or 0.2 }) end)
																																row.Activated:Connect(function()
																																				local o = row._opt
																																				if not dMulti then for k in pairs(selected) do selected[k] = false end end
																																				selected[o] = not selected[o]
																																				updateList()
																																				refreshLabel()
																																				if dCb then
																																								if dMulti then
																																												local vals = {}
																																												for _, vo in ipairs(dOpts) do if selected[vo] then vals[#vals+1] = vo end end
																																												callCallback("Dropdown", dCb, vals)
																																								else
																																												for _, vo in ipairs(dOpts) do if selected[vo] then callCallback("Dropdown", dCb, vo); break end end
																																								end
																																				end
																																				changed:Fire(getValue())
																																				if not dMulti then closeMenu() end
																																end)
																																row._lbl = lbl; row._tick = tick; pool[activeCount] = row
																												end

																												row.Visible = true
																												row._opt = opt
																												row._lbl.Text = opt
																												row._tick.Text = selected[opt] and "✓" or ""
																												row.BackgroundTransparency = selected[opt] and 0 or 0.2
																												row.Position = UDim2.new(0, 0, 0, virtualList:GetOffset(i))
																								end

																								for i = activeCount + 1, #pool do pool[i].Visible = false end
																				end

																				mf:GetPropertyChangedSignal("CanvasPosition"):Connect(updateList)
																				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
																								local query = searchBox.Text:lower()
																								filteredOpts = {}
																								for _, o in ipairs(dOpts) do
																												if query == "" or o:lower():find(query, 1, true) then table.insert(filteredOpts, o) end
																								end
																								mf.CanvasPosition = Vector2.new(0, 0)
																								updateList()
																				end)

																				updateList()
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

				local row = makeRow(bName, 40)
				rowNameLabel(row, bName)

				local btn = mkButton({
					AnchorPoint            = Vector2.new(1, 0.5),
					Position               = UDim2.new(1, -10, 0.5, 0),
					Size                   = UDim2.new(0, 108, 0, 26),
					BackgroundColor3       = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					ZIndex                 = 6,
				}, row)
				corner(btn, 0)
				stroke(btn, 1, T.Border)
				redGrad(btn)
				local btnLbl = mkLabel({
					Size           = UDim2.new(1, 0, 1, 0),
					Text           = bText,
					TextSize       = 13,
					Font           = Enum.Font.GothamBold,
					TextColor3     = T.Text,
					ZIndex         = 8,
				}, btn)
				btn.Active = not disabled
				if disabled then btn.BackgroundTransparency = 0.45 end

				local btnOverlay = Instance.new("Frame")
				btnOverlay.Size                = UDim2.new(1, 0, 1, 0)
				btnOverlay.BackgroundColor3    = Color3.new(1, 1, 1)
				btnOverlay.BackgroundTransparency = 1
				btnOverlay.ZIndex              = 7
				btnOverlay.Parent              = btn

				btn.MouseEnter:Connect(function() tw(btnOverlay, { BackgroundTransparency = 0.82 }) end)
				btn.MouseLeave:Connect(function() tw(btnOverlay, { BackgroundTransparency = 1 }) end)
				btn.Activated:Connect(function()
					if disabled then return end
					tw(btnOverlay, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75 })
					task.delay(0.08, function()
						tw(btnOverlay, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 })
					end)
					callCallback("Button", bCb)
				end)

				local ctrl = { _row = row, _name = bName }
				function ctrl:Press() if not disabled then callCallback("Button", bCb) end end
				function ctrl:SetText(t) btnLbl.Text = t end
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

				local row = makeRow(iName, 40)
				rowNameLabel(row, iName)

				local wrap = Instance.new("Frame")
				wrap.AnchorPoint            = Vector2.new(1, 0.5)
				wrap.Position               = UDim2.new(1, -10, 0.5, 0)
				wrap.Size                   = UDim2.new(0, 160, 0, 26)
				wrap.BackgroundColor3       = T.SurfaceHi
				wrap.BackgroundTransparency = 0
				wrap.ZIndex                 = 6
				wrap.Parent                 = row
				corner(wrap, 2)
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

				local row = makeRow("_lbl", 32)
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

				local row = makeRow(kName, 40)
				rowNameLabel(row, kName)

				local kBtn = mkButton({
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -10, 0.5, 0),
					Size             = UDim2.new(0, 96, 0, 26),
					BackgroundColor3 = T.SurfaceHi,
					BackgroundTransparency = 0,
					ZIndex           = 6,
				}, row)
				corner(kBtn, 2)
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

			function Section:ImageList(c2)
				c2 = c2 or {}
				Window:_validateControlId(c2, "ImageList")
				Validation.warnUnknown(c2, { "Id", "Name", "Items", "Columns", "ImageSize", "Callback" }, "ImageList")
				local iName   = c2.Name      or "Images"
				local items   = c2.Items     or {}
				local cols    = c2.Columns   or 3
				local imgPx   = c2.ImageSize or 58
				local callback = c2.Callback

				local labelH  = 18
				local cellGap = 4
				local cellH   = imgPx + labelH + 2
				local gridW   = cols * imgPx + (cols - 1) * cellGap
				local padV    = 8
				local nrows   = math.max(1, math.ceil(#items / cols))
				local gridH   = nrows * cellH + (nrows - 1) * cellGap
				local rowH    = gridH + padV * 2

				local row = makeRow(iName, rowH)

				local grid = Instance.new("Frame")
				grid.AnchorPoint         = Vector2.new(0.5, 0.5)
				grid.Position            = UDim2.new(0.5, 0, 0.5, 0)
				grid.Size                = UDim2.new(0, gridW, 0, gridH)
				grid.BackgroundTransparency = 1
				grid.ZIndex              = 6
				grid.Parent              = row

				local layout = Instance.new("UIGridLayout")
				layout.CellSize          = UDim2.new(0, imgPx, 0, cellH)
				layout.CellPadding       = UDim2.new(0, cellGap, 0, cellGap)
				layout.SortOrder         = Enum.SortOrder.LayoutOrder
				layout.Parent            = grid

				for idx, item in ipairs(items) do
					local assetId = type(item) == "table" and (item.Id or item.Asset or "") or tostring(item)
					local caption = type(item) == "table" and (item.Name or item.Label or "") or ""

					local cell = mkButton({
						Size                   = UDim2.new(0, imgPx, 0, cellH),
						BackgroundColor3       = T.SurfaceHover,
						BackgroundTransparency = 0.3,
						ZIndex                 = 6,
						LayoutOrder            = idx,
					}, grid)
					stroke(cell, 1, T.Border)

					local imgLbl = Instance.new("ImageLabel")
					imgLbl.Size                   = UDim2.new(1, 0, 0, imgPx)
					imgLbl.BackgroundTransparency = 1
					imgLbl.Image                  = assetId
					imgLbl.ScaleType              = Enum.ScaleType.Fit
					imgLbl.ImageColor3            = Color3.new(1, 1, 1)
					imgLbl.ZIndex                 = 7
					imgLbl.Parent                 = cell

					if caption ~= "" then
						mkLabel({
							Position       = UDim2.new(0, 0, 0, imgPx + 2),
							Size           = UDim2.new(1, 0, 0, labelH),
							Text           = caption,
							TextSize       = 11,
							Font           = Enum.Font.Gotham,
							TextColor3     = T.TextSub,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextTruncate   = Enum.TextTruncate.AtEnd,
							ZIndex         = 7,
						}, cell)
					end

					cell.MouseEnter:Connect(function() tw(cell, { BackgroundTransparency = 0 }) end)
					cell.MouseLeave:Connect(function() tw(cell, { BackgroundTransparency = 0.3 }) end)

					if callback then
						cell.Activated:Connect(function()
							callCallback("ImageList", callback, item)
						end)
					end
				end

				local ctrl = { _row = row, _name = iName }
				function ctrl:Destroy() Window:_unregisterControl(self); row:Destroy() end
				function ctrl:SetVisible(v) row.Visible = v end

				Window:_registerControl(ctrl, c2, "ImageList")
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			return Section
		end

		return Tab
	end

	-- ── Search ───────────────────────────────────────────────────────────────
	local function applySearch(query)
		local q = query:lower()
		for _, el in ipairs(Window._allElements) do
			if el._row and el._name then
				el._row.Visible = q == "" or el._name:lower():find(q, 1, true) ~= nil
			end
		end
		for _, sec in ipairs(Window._sections) do
			if q == "" then
				sec._wrap.Visible = true
				sec._content.Visible = true
			else
				local any = false
				for _, el in ipairs(sec._elements) do
					if el._row and el._row.Visible then
						any = true
						break
					end
				end
				sec._wrap.Visible = any
				if any then sec._content.Visible = true end
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
