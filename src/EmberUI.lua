--!strict
--[[
	EmberUI  v1.0.0
	A high-quality Roblox UI library.

	API:
	  local UI = require(path.to.EmberUI)

	  local Win = UI:Window({ Title = "My Hub" })
	  Win:SideButton("Discord", function() end)

	  local Tab = Win:Tab("Farm")
	  local Sec = Tab:Section("Auto Steal")

	  local tog = Sec:Toggle({ Name = "Auto Steal", Default = false,
	                           Callback = function(v) end })
	  tog:Set(true)
	  tog:GetNote()  tog:SetNote("text")

	  local sl  = Sec:Slider({ Name = "Speed", Min = 0, Max = 200, Default = 16 })
	  local dd  = Sec:Dropdown({ Name = "Areas", Options = {"A","B"}, Multi = true })
	  local btn = Sec:Button({ Name = "Teleport", Text = "Go",
	                           Callback = function() end })
	  local inp = Sec:Input({ Name = "Value", Placeholder = "0..100",
	                          Callback = function(v) end })
	  local lbl = Sec:Label({ Text = "Hello world" })

	  -- States (reactive values)
	  local s = UI.State(false)
	  s:Sub(function(v) print(v) end)
	  tog:Bind(s)   -- toggle drives state AND state drives toggle

	  Win:Search("filter text")  -- programmatic search
	  Win:Destroy()
]]

-- ────────────────────────────────────────────────────────────────────────────
--  Services
-- ────────────────────────────────────────────────────────────────────────────
local Players         = game:GetService("Players")
local UserInputService= game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ────────────────────────────────────────────────────────────────────────────
--  Theme
-- ────────────────────────────────────────────────────────────────────────────
local T = {
	-- Backgrounds
	Bg          = Color3.fromRGB(13, 13, 18),
	Surface     = Color3.fromRGB(20, 20, 28),
	SurfaceHi   = Color3.fromRGB(30, 30, 40),
	-- Accent  (warm orange-red — not Chilli's flat crimson)
	Accent      = Color3.fromRGB(218, 78, 36),
	AccentDark  = Color3.fromRGB(150, 42, 14),
	AccentFaint = Color3.fromRGB(218, 78, 36),   -- used at low opacity
	-- Text
	Text        = Color3.fromRGB(245, 245, 250),
	TextSub     = Color3.fromRGB(150, 150, 170),
	TextHint    = Color3.fromRGB(90,  90, 110),
	-- UI chrome
	Border      = Color3.fromRGB(44, 44, 60),
	BorderHi    = Color3.fromRGB(70, 70, 95),
	-- State colours
	On          = Color3.fromRGB(68, 200, 92),
	OnDark      = Color3.fromRGB(38, 130, 52),
	Off         = Color3.fromRGB(48, 48, 65),
	OffDark     = Color3.fromRGB(30, 30, 44),
}

-- ────────────────────────────────────────────────────────────────────────────
--  Utility helpers
-- ────────────────────────────────────────────────────────────────────────────
local function corner(p: Instance, r: number)
	local c   = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent  = p
	return c
end

local function stroke(p: Instance, thickness: number, col: Color3, trans: number?)
	local s             = Instance.new("UIStroke")
	s.Thickness         = thickness
	s.Color             = col
	s.Transparency      = trans or 0
	s.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
	s.Parent            = p
	return s
end

local function grad(p: Instance, c0: Color3, c1: Color3, rot: number?)
	local g   = Instance.new("UIGradient")
	g.Color   = ColorSequence.new(c0, c1)
	g.Rotation= rot or 90
	g.Parent  = p
	return g
end

local function pad(p: Instance, l: number, r: number, t: number, b: number)
	local u         = Instance.new("UIPadding")
	u.PaddingLeft   = UDim.new(0, l)
	u.PaddingRight  = UDim.new(0, r)
	u.PaddingTop    = UDim.new(0, t)
	u.PaddingBottom = UDim.new(0, b)
	u.Parent        = p
	return u
end

local function listLayout(p: Instance, dir: Enum.FillDirection?, spacing: number?)
	local l         = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding       = UDim.new(0, spacing or 0)
	l.SortOrder     = Enum.SortOrder.LayoutOrder
	l.Parent        = p
	return l
end

local function tween(obj: Instance, t2: number, props: {[string]: any})
	TweenService:Create(obj, TweenInfo.new(t2, Enum.EasingStyle.Quad), props):Play()
end

local function newFrame(parent: Instance?, props: {[string]: any}?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	if props then for k,v in pairs(props) do (f :: any)[k] = v end end
	if parent then f.Parent = parent end
	return f
end

local function newLabel(parent: Instance?, props: {[string]: any}?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font      = Enum.Font.GothamBold
	l.TextColor3= T.Text
	l.TextSize  = 14
	l.TextScaled= false
	l.RichText  = false
	if props then for k,v in pairs(props) do (l :: any)[k] = v end end
	if parent then l.Parent = parent end
	return l
end

local function newButton(parent: Instance?, props: {[string]: any}?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Font      = Enum.Font.GothamBold
	b.TextColor3= T.Text
	b.TextSize  = 14
	b.AutoButtonColor = false
	b.Text      = ""
	if props then for k,v in pairs(props) do (b :: any)[k] = v end end
	if parent then b.Parent = parent end
	return b
end

-- ────────────────────────────────────────────────────────────────────────────
--  State  (reactive value container)
-- ────────────────────────────────────────────────────────────────────────────
local function State(default: any)
	local self = { _val = default, _subs = {} }

	function self:Get() return self._val end

	function self:Set(v: any)
		if v == self._val then return end
		self._val = v
		for _, cb in ipairs(self._subs) do
			pcall(cb, v)
		end
	end

	function self:Sub(cb: (any) -> ())
		table.insert(self._subs, cb)
		return function()   -- unsubscribe handle
			for i, s in ipairs(self._subs) do
				if s == cb then table.remove(self._subs, i) break end
			end
		end
	end

	return self
end

-- ────────────────────────────────────────────────────────────────────────────
--  Dragging
-- ────────────────────────────────────────────────────────────────────────────
local function makeDraggable(handle: GuiObject, target: GuiObject)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		dragging  = true
		dragStart = inp.Position
		startPos  = target.Position
		inp.Changed:Connect(function()
			if inp.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end)
	handle.InputChanged:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if not dragging then return end
		local d = inp.Position - dragStart
		target.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y
		)
	end)
end

-- ────────────────────────────────────────────────────────────────────────────
--  Root UI parent  (uses gethui if available, else CoreGui → PlayerGui)
-- ────────────────────────────────────────────────────────────────────────────
local function getRoot(): Instance
	if _G.gethui then return _G.gethui() end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- ════════════════════════════════════════════════════════════════════════════
--  WINDOW
-- ════════════════════════════════════════════════════════════════════════════
local function buildWindow(cfg: {[string]: any})
	cfg.Title     = cfg.Title     or "EmberUI"
	cfg.Width     = cfg.Width     or 660
	cfg.Height    = cfg.Height    or 520
	cfg.MinWidth  = cfg.MinWidth  or 400
	cfg.MinHeight = cfg.MinHeight or 300

	-- ── ScreenGui ───────────────────────────────────────────────────────────
	local gui = Instance.new("ScreenGui")
	gui.Name           = "EmberUI_" .. cfg.Title:gsub("%s","")
	gui.ResetOnSpawn   = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent         = getRoot()

	-- ── Outer window frame ───────────────────────────────────────────────────
	local win = Instance.new("Frame")
	win.Name                  = "Window"
	win.AnchorPoint           = Vector2.new(0.5, 0.5)
	win.Position              = UDim2.new(0.5, 0, 0.5, 0)
	win.Size                  = UDim2.new(0, cfg.Width, 0, cfg.Height)
	win.BackgroundColor3      = T.Bg
	win.BackgroundTransparency= 0.06
	win.ClipsDescendants      = false
	win.Parent                = gui
	corner(win, 10)
	stroke(win, 1.5, T.Border)

	-- ── Title bar ────────────────────────────────────────────────────────────
	local TOPBAR_H = 48
	local topBar = Instance.new("Frame")
	topBar.Name              = "TopBar"
	topBar.Size              = UDim2.new(1, 0, 0, TOPBAR_H)
	topBar.BackgroundColor3  = T.AccentDark
	topBar.ZIndex            = 6
	topBar.Parent            = win
	corner(topBar, 10)
	grad(topBar, T.Accent, T.AccentDark, 90)
	-- cover bottom rounded corners
	local topFix = newFrame(topBar, {
		Size             = UDim2.new(1, 0, 0, 12),
		Position         = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = T.AccentDark,
		ZIndex           = 5,
	})
	grad(topFix, T.Accent, T.AccentDark, 90)

	-- Title text
	local titleLbl = newLabel(topBar, {
		Size             = UDim2.new(1, -100, 1, 0),
		Position         = UDim2.new(0, 16, 0, 0),
		Text             = cfg.Title,
		Font             = Enum.Font.GothamBlack,
		TextSize         = 20,
		TextXAlignment   = Enum.TextXAlignment.Left,
		ZIndex           = 7,
	})
	local ts = Instance.new("UIStroke")
	ts.Color       = Color3.new(0, 0, 0)
	ts.Thickness   = 1.5
	ts.Transparency= 0.5
	ts.Parent      = titleLbl

	-- Close button
	local closeBtn = newButton(topBar, {
		Name             = "CloseBtn",
		Size             = UDim2.new(0, 32, 0, 32),
		Position         = UDim2.new(1, -44, 0.5, 0),
		AnchorPoint      = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(200, 50, 50),
		BackgroundTransparency = 0,
		Text             = "✕",
		TextSize         = 15,
		ZIndex           = 8,
	})
	corner(closeBtn, 6)
	stroke(closeBtn, 1, Color3.fromRGB(100, 20, 20))
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.12, { BackgroundColor3 = Color3.fromRGB(230, 60, 60) })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.12, { BackgroundColor3 = Color3.fromRGB(200, 50, 50) })
	end)

	makeDraggable(topBar, win)

	-- ── Left sidebar ─────────────────────────────────────────────────────────
	local SIDEBAR_W = 130
	local SIDEBAR_GAP = 6

	local leftSide = Instance.new("Frame")
	leftSide.Name                  = "LeftSidebar"
	leftSide.AnchorPoint           = Vector2.new(1, 0)
	leftSide.Position              = UDim2.new(0, -SIDEBAR_GAP, 0, TOPBAR_H)
	leftSide.Size                  = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H)
	leftSide.BackgroundColor3      = T.Bg
	leftSide.BackgroundTransparency= 0.06
	leftSide.ClipsDescendants      = true
	leftSide.ZIndex                = 3
	leftSide.Parent                = win
	corner(leftSide, 8)
	stroke(leftSide, 1, T.Border)
	pad(leftSide, 6, 6, 8, 8)
	listLayout(leftSide, Enum.FillDirection.Vertical, 5)

	-- ── Right sidebar ─────────────────────────────────────────────────────────
	local rightSide = Instance.new("Frame")
	rightSide.Name                  = "RightSidebar"
	rightSide.Position              = UDim2.new(1, SIDEBAR_GAP, 0, TOPBAR_H)
	rightSide.Size                  = UDim2.new(0, SIDEBAR_W, 0, 0)
	rightSide.AutomaticSize         = Enum.AutomaticSize.Y
	rightSide.BackgroundColor3      = T.Bg
	rightSide.BackgroundTransparency= 0.06
	rightSide.ClipsDescendants      = true
	rightSide.ZIndex                = 3
	rightSide.Parent                = win
	corner(rightSide, 8)
	stroke(rightSide, 1, T.Border)
	pad(rightSide, 6, 6, 8, 8)
	listLayout(rightSide, Enum.FillDirection.Vertical, 5)

	-- ── Content area ──────────────────────────────────────────────────────────
	local BOTTOM_H = 40
	local contentArea = newFrame(win, {
		Name     = "Content",
		Position = UDim2.new(0, 0, 0, TOPBAR_H),
		Size     = UDim2.new(1, 0, 1, -(TOPBAR_H + BOTTOM_H)),
		ZIndex   = 2,
	})

	-- ── Search / bottom bar ───────────────────────────────────────────────────
	local searchBar = Instance.new("Frame")
	searchBar.Name                 = "SearchBar"
	searchBar.AnchorPoint          = Vector2.new(0, 1)
	searchBar.Position             = UDim2.new(0, 0, 1, 0)
	searchBar.Size                 = UDim2.new(1, 0, 0, BOTTOM_H)
	searchBar.BackgroundColor3     = T.Surface
	searchBar.BackgroundTransparency = 0.1
	searchBar.ZIndex               = 6
	searchBar.Parent               = win
	stroke(searchBar, 1, T.Border)
	-- cover top rounded corners of search bar
	local sbFix = newFrame(searchBar, {
		Size             = UDim2.new(1, 0, 0, 10),
		Position         = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = T.Surface,
		BackgroundTransparency = 0.1,
		ZIndex           = 5,
	})

	local searchIcon = newLabel(searchBar, {
		Size           = UDim2.new(0, 70, 1, 0),
		Position       = UDim2.new(0, 10, 0, 0),
		Text           = "🔍  Search",
		TextSize       = 13,
		TextColor3     = T.TextSub,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font           = Enum.Font.Gotham,
		ZIndex         = 7,
	})

	local searchDivider = newFrame(searchBar, {
		Size             = UDim2.new(0, 1, 0.6, 0),
		Position         = UDim2.new(0, 82, 0.2, 0),
		BackgroundColor3 = T.Border,
		BackgroundTransparency = 0,
		ZIndex           = 7,
	})

	local searchBox = Instance.new("TextBox")
	searchBox.Name             = "SearchInput"
	searchBox.Size             = UDim2.new(1, -95, 1, -12)
	searchBox.Position         = UDim2.new(0, 88, 0, 6)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText  = "Filter features..."
	searchBox.PlaceholderColor3= T.TextHint
	searchBox.TextColor3       = T.Text
	searchBox.Font             = Enum.Font.Gotham
	searchBox.TextSize         = 13
	searchBox.TextXAlignment   = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.ZIndex           = 7
	searchBox.Parent           = searchBar

	-- ── Tab page container ────────────────────────────────────────────────────
	local pages = newFrame(contentArea, {
		Name = "Pages",
		Size = UDim2.new(1, 0, 1, 0),
	})

	-- ════════════════════════════════════════════════════════════════════════
	--  Window object
	-- ════════════════════════════════════════════════════════════════════════
	local Window = {}
	Window._tabs        = {}
	Window._activeTab   = nil
	Window._allElements = {}   -- flat list for search
	Window._gui         = gui
	Window._win         = win

	-- ── Sidebar utility button ────────────────────────────────────────────────
	function Window:SideButton(name: string, callback: ()->())
		local btn = newButton(rightSide, {
			Name             = name,
			Size             = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = T.Accent,
			BackgroundTransparency = 0,
			Text             = "",
			ZIndex           = 4,
		})
		corner(btn, 7)
		stroke(btn, 1, T.AccentDark)
		grad(btn, T.Accent, T.AccentDark, 90)

		local lbl = newLabel(btn, {
			Size           = UDim2.new(1, 0, 1, 0),
			Text           = name,
			TextSize       = 14,
			ZIndex         = 5,
		})
		local ls = Instance.new("UIStroke")
		ls.Color      = Color3.new(0, 0, 0)
		ls.Thickness  = 1
		ls.Transparency = 0.4
		ls.Parent     = lbl

		btn.MouseEnter:Connect(function()
			tween(btn, 0.1, { BackgroundColor3 = T.AccentLight })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.1, { BackgroundColor3 = T.Accent })
		end)
		btn.MouseButton1Click:Connect(function()
			pcall(callback)
		end)
		return btn
	end

	-- ── Tab ───────────────────────────────────────────────────────────────────
	function Window:Tab(name: string)
		-- Left sidebar button
		local tabBtn = newButton(leftSide, {
			Name             = name,
			Size             = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = T.SurfaceHi,
			BackgroundTransparency = 0,
			Text             = "",
			ZIndex           = 4,
		})
		corner(tabBtn, 7)
		stroke(tabBtn, 1, T.Border)

		local tabLbl = newLabel(tabBtn, {
			Size           = UDim2.new(1, 0, 1, 0),
			Text           = name,
			TextSize       = 14,
			ZIndex         = 5,
		})

		-- Tab page (scrollable)
		local page = Instance.new("ScrollingFrame")
		page.Name                     = name .. "_Page"
		page.Size                     = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency   = 1
		page.ScrollBarThickness       = 4
		page.ScrollBarImageColor3     = T.Accent
		page.CanvasSize               = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize      = Enum.AutomaticSize.Y
		page.Visible                  = false
		page.ZIndex                   = 3
		page.Parent                   = pages
		pad(page, 10, 10, 8, 8)
		listLayout(page, Enum.FillDirection.Vertical, 6)

		local function activate()
			-- deactivate current
			if Window._activeTab then
				local old = Window._activeTab
				old._page.Visible = false
				tween(old._btn, 0.12, { BackgroundColor3 = T.SurfaceHi })
				for _, g in ipairs(old._btn:GetDescendants()) do
					if g:IsA("UIGradient") then g:Destroy() end
				end
				stroke(old._btn, 1, T.Border)
			end
			-- activate this
			page.Visible = true
			for _, s2 in ipairs(tabBtn:GetDescendants()) do
				if s2:IsA("UIStroke") then s2:Destroy() end
			end
			tween(tabBtn, 0.12, { BackgroundColor3 = T.Accent })
			grad(tabBtn, T.Accent, T.AccentDark, 90)
			stroke(tabBtn, 1, T.AccentDark)
			Window._activeTab = Tab
		end

		tabBtn.MouseButton1Click:Connect(activate)
		tabBtn.MouseEnter:Connect(function()
			if Window._activeTab ~= Tab then
				tween(tabBtn, 0.1, { BackgroundColor3 = T.BorderHi })
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if Window._activeTab ~= Tab then
				tween(tabBtn, 0.1, { BackgroundColor3 = T.SurfaceHi })
			end
		end)

		-- ── Tab object ────────────────────────────────────────────────────────
		local Tab = {}
		Tab._btn  = tabBtn
		Tab._page = page
		Tab._win  = Window

		-- ── Section ───────────────────────────────────────────────────────────
		function Tab:Section(name: string, expanded: boolean?)
			expanded = if expanded == nil then true else expanded

			-- Section container
			local secWrap = Instance.new("Frame")
			secWrap.Name            = name .. "_Sec"
			secWrap.Size            = UDim2.new(1, 0, 0, 0)
			secWrap.AutomaticSize   = Enum.AutomaticSize.Y
			secWrap.BackgroundColor3= T.Surface
			secWrap.BackgroundTransparency = 0.05
			secWrap.ZIndex          = 4
			secWrap.Parent          = page
			corner(secWrap, 8)
			stroke(secWrap, 1, T.Border)

			local secList = Instance.new("UIListLayout")
			secList.FillDirection = Enum.FillDirection.Vertical
			secList.Padding       = UDim.new(0, 0)
			secList.SortOrder     = Enum.SortOrder.LayoutOrder
			secList.Parent        = secWrap

			-- Header
			local hdr = Instance.new("Frame")
			hdr.Name             = "Header"
			hdr.LayoutOrder      = 0
			hdr.Size             = UDim2.new(1, 0, 0, 38)
			hdr.BackgroundColor3 = T.SurfaceHi
			hdr.BackgroundTransparency = 0
			hdr.ZIndex           = 5
			hdr.Parent           = secWrap
			corner(hdr, 8)
			stroke(hdr, 1, T.Border)

			-- hide bottom corners of header (blends into rows below)
			local hdrFix = newFrame(hdr, {
				Size             = UDim2.new(1, 0, 0, 10),
				Position         = UDim2.new(0, 0, 1, -10),
				BackgroundColor3 = T.SurfaceHi,
				ZIndex           = 4,
			})

			-- Chevron
			local chevron = newLabel(hdr, {
				Size           = UDim2.new(0, 20, 1, 0),
				Position       = UDim2.new(0, 10, 0, 0),
				Text           = expanded and "⌄" or "›",
				TextSize       = 18,
				TextColor3     = T.TextSub,
				ZIndex         = 6,
			})

			local hdrLbl = newLabel(hdr, {
				Size           = UDim2.new(1, -36, 1, 0),
				Position       = UDim2.new(0, 32, 0, 0),
				Text           = name,
				TextSize       = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex         = 6,
			})

			local hdrBtn = newButton(hdr, {
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 7,
			})

			-- Content frame (holds rows)
			local contentFrame = newFrame(secWrap, {
				Name          = "Content",
				LayoutOrder   = 1,
				Size          = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible       = expanded,
				ZIndex        = 4,
			})
			listLayout(contentFrame, Enum.FillDirection.Vertical, 0)

			hdrBtn.MouseButton1Click:Connect(function()
				contentFrame.Visible = not contentFrame.Visible
				chevron.Text = contentFrame.Visible and "⌄" or "›"
			end)

			-- ── Section object ─────────────────────────────────────────────────
			local Section = {}
			Section._content  = contentFrame
			Section._elements = {}

			-- ── Row builder helpers ────────────────────────────────────────────
			local function makeRow(rowName: string, h: number)
				local row = Instance.new("Frame")
				row.Name             = rowName
				row.Size             = UDim2.new(1, 0, 0, h)
				row.BackgroundColor3 = T.Surface
				row.BackgroundTransparency = 0.15
				row.ZIndex           = 5
				row.Parent           = contentFrame

				-- thin separator line on top
				local sep = newFrame(row, {
					Size             = UDim2.new(1, 0, 0, 1),
					Position         = UDim2.new(0, 0, 0, 0),
					BackgroundColor3 = T.Border,
					BackgroundTransparency = 0.3,
					ZIndex           = 6,
				})

				return row
			end

			local function rowLabel(row: Frame, text: string, x: number, y: number, w: number, sz: number?, col: Color3?)
				return newLabel(row, {
					Position       = UDim2.new(0, x, 0, y),
					Size           = UDim2.new(0, w, 1, 0),
					Text           = text,
					TextSize       = sz or 14,
					TextColor3     = col or T.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Font           = Enum.Font.GothamBold,
					ZIndex         = 6,
				})
			end

			local function makeNote(row: Frame)
				local noteLbl = newLabel(row, {
					Name           = "_note",
					Position       = UDim2.new(0, 12, 0, 0),
					Size           = UDim2.new(1, -60, 0, 16),
					TextSize       = 11,
					TextColor3     = T.TextSub,
					Font           = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					Visible        = false,
					ZIndex         = 6,
				})
				return noteLbl
			end

			-- ── TOGGLE ────────────────────────────────────────────────────────
			function Section:Toggle(cfg2: {[string]: any})
				cfg2 = cfg2 or {}
				local name2    = cfg2.Name     or "Toggle"
				local default  = cfg2.Default  or false
				local callback = cfg2.Callback

				local ROW_H = cfg2.Note and 56 or 44
				local row   = makeRow(name2, ROW_H)

				local nameLbl  = rowLabel(row, name2, 12, 0, 260, 14, T.Text)
				nameLbl.Size   = UDim2.new(1, -60, 0, 26)
				nameLbl.Position= UDim2.new(0, 12, 0, cfg2.Note and 6 or 0)

				local noteLbl = makeNote(row)
				noteLbl.Position = UDim2.new(0, 12, 0, 28)
				if cfg2.Note then
					noteLbl.Text    = cfg2.Note
					noteLbl.Visible = true
					row.Size        = UDim2.new(1, 0, 0, 56)
				end

				-- Pill track
				local PILL_W, PILL_H = 42, 22
				local pill = Instance.new("Frame")
				pill.Name                  = "Pill"
				pill.AnchorPoint           = Vector2.new(0, 0.5)
				pill.Position              = UDim2.new(1, -(PILL_W + 12), 0.5, 0)
				pill.Size                  = UDim2.new(0, PILL_W, 0, PILL_H)
				pill.BackgroundColor3      = T.Off
				pill.ZIndex                = 6
				pill.Parent                = row
				corner(pill, PILL_H)
				stroke(pill, 1, T.OffDark)

				-- Knob
				local KNOB = PILL_H - 6
				local knob = Instance.new("Frame")
				knob.AnchorPoint         = Vector2.new(0, 0.5)
				knob.Position            = UDim2.new(0, 3, 0.5, 0)
				knob.Size                = UDim2.new(0, KNOB, 0, KNOB)
				knob.BackgroundColor3    = T.Text
				knob.ZIndex              = 7
				knob.Parent              = pill
				corner(knob, KNOB)

				-- Hit area
				local hit = newButton(row, {
					Size  = UDim2.new(1, 0, 1, 0),
					ZIndex= 8,
				})

				local value = default
				local _state = nil

				local function apply(v: boolean, fire: boolean?)
					value = v
					local onPos  = UDim2.new(0, PILL_W - KNOB - 3, 0.5, 0)
					local offPos = UDim2.new(0, 3, 0.5, 0)
					tween(knob, 0.15, { Position = v and onPos or offPos })
					tween(pill, 0.15, { BackgroundColor3 = v and T.On or T.Off })
					if fire ~= false and callback then pcall(callback, v) end
					if _state then _state:Set(v) end
				end

				apply(default, false)

				hit.MouseButton1Click:Connect(function()
					apply(not value)
				end)

				-- Controller
				local ctrl = {}
				ctrl._row  = row
				ctrl._name = name2

				function ctrl:Set(v: boolean, fire: boolean?)
					apply(v, fire)
				end
				function ctrl:Get(): boolean return value end
				function ctrl:SetNote(txt: string)
					noteLbl.Text    = txt
					noteLbl.Visible = txt ~= ""
					row.Size = UDim2.new(1, 0, 0, txt ~= "" and 56 or 44)
				end
				function ctrl:GetNote(): string return noteLbl.Text end
				function ctrl:Bind(state)
					_state = state
					state:Sub(function(v) apply(v, false) end)
					apply(state:Get(), false)
				end
				function ctrl:Destroy() row:Destroy() end
				function ctrl:SetVisible(v: boolean) row.Visible = v end

				table.insert(Window._allElements, ctrl)
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── SLIDER ────────────────────────────────────────────────────────
			function Section:Slider(cfg2: {[string]: any})
				cfg2 = cfg2 or {}
				local name2    = cfg2.Name     or "Slider"
				local minV     = cfg2.Min      or 0
				local maxV     = cfg2.Max      or 100
				local default  = math.clamp(cfg2.Default or minV, minV, maxV)
				local decimals = cfg2.Decimals or 0
				local suffix   = cfg2.Suffix   or ""
				local callback = cfg2.Callback

				local row = makeRow(name2, 58)

				local nameLbl = rowLabel(row, name2, 12, 6, 200)

				-- Value label (right side)
				local valLbl = newLabel(row, {
					AnchorPoint    = Vector2.new(1, 0),
					Position       = UDim2.new(1, -12, 0, 6),
					Size           = UDim2.new(0, 80, 0, 22),
					TextSize       = 13,
					TextColor3     = T.TextSub,
					TextXAlignment = Enum.TextXAlignment.Right,
					Font           = Enum.Font.GothamBold,
					ZIndex         = 6,
				})

				-- Track
				local trackBg = Instance.new("Frame")
				trackBg.Name             = "Track"
				trackBg.Position         = UDim2.new(0, 12, 0, 36)
				trackBg.Size             = UDim2.new(1, -24, 0, 6)
				trackBg.BackgroundColor3 = T.SurfaceHi
				trackBg.ZIndex           = 6
				trackBg.Parent           = row
				corner(trackBg, 3)
				stroke(trackBg, 1, T.Border)

				local trackFill = Instance.new("Frame")
				trackFill.Name           = "Fill"
				trackFill.Size           = UDim2.new(0, 0, 1, 0)
				trackFill.BackgroundColor3=T.Accent
				trackFill.ZIndex         = 7
				trackFill.Parent         = trackBg
				corner(trackFill, 3)
				grad(trackFill, T.AccentLight, T.Accent, 0)

				local handle = Instance.new("Frame")
				handle.Name              = "Handle"
				handle.AnchorPoint       = Vector2.new(0.5, 0.5)
				handle.Size              = UDim2.new(0, 14, 0, 14)
				handle.BackgroundColor3  = T.Text
				handle.ZIndex            = 8
				handle.Parent            = trackBg
				corner(handle, 7)
				stroke(handle, 1.5, T.Accent)

				local value = default

				local function updateVisual(v: number)
					local pct = (v - minV) / math.max(maxV - minV, 1e-9)
					trackFill.Size = UDim2.new(pct, 0, 1, 0)
					handle.Position = UDim2.new(pct, 0, 0.5, 0)
					local fmt = decimals > 0
						and ("%." .. decimals .. "f%s"):format(v, suffix)
						or  ("%d%s"):format(math.floor(v + 0.5), suffix)
					valLbl.Text = fmt
				end

				updateVisual(default)

				-- Drag logic
				local draggingSlider = false
				local hitArea = newButton(trackBg, {
					Size  = UDim2.new(1, 0, 0, 22),
					Position = UDim2.new(0, 0, 0.5, -11),
					ZIndex = 9,
				})

				local function setFromMouse(mx: number)
					local abs = trackBg.AbsolutePosition
					local sz  = trackBg.AbsoluteSize
					local pct = math.clamp((mx - abs.X) / sz.X, 0, 1)
					local raw = minV + pct * (maxV - minV)
					local step = 1 / (10 ^ decimals)
					value = math.floor(raw / step + 0.5) * step
					value = math.clamp(value, minV, maxV)
					updateVisual(value)
					if callback then pcall(callback, value) end
				end

				hitArea.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingSlider = true
						setFromMouse(inp.Position.X)
					end
				end)

				UserInputService.InputChanged:Connect(function(inp)
					if draggingSlider and inp.UserInputType == Enum.UserInputType.MouseMovement then
						setFromMouse(inp.Position.X)
					end
				end)

				UserInputService.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingSlider = false
					end
				end)

				local ctrl = {}
				ctrl._row  = row
				ctrl._name = name2
				function ctrl:Set(v: number, fire: boolean?)
					value = math.clamp(v, minV, maxV)
					updateVisual(value)
					if fire ~= false and callback then pcall(callback, value) end
				end
				function ctrl:Get(): number return value end
				function ctrl:SetRange(mn: number, mx: number)
					minV = mn; maxV = mx
					value = math.clamp(value, minV, maxV)
					updateVisual(value)
				end
				function ctrl:Destroy() row:Destroy() end
				function ctrl:SetVisible(v: boolean) row.Visible = v end

				table.insert(Window._allElements, ctrl)
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── DROPDOWN ─────────────────────────────────────────────────────
			function Section:Dropdown(cfg2: {[string]: any})
				cfg2 = cfg2 or {}
				local name2    = cfg2.Name     or "Dropdown"
				local options  = cfg2.Options  or {}
				local multi    = cfg2.Multi    or false
				local default  = cfg2.Default
				local callback = cfg2.Callback

				local row = makeRow(name2, 44)
				rowLabel(row, name2, 12, 0, 200)

				-- Pill dropdown button
				local PILL_W = 160
				local ddBtn = newButton(row, {
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -10, 0.5, 0),
					Size             = UDim2.new(0, PILL_W, 0, 28),
					BackgroundColor3 = T.SurfaceHi,
					BackgroundTransparency = 0,
					ZIndex           = 6,
				})
				corner(ddBtn, 6)
				stroke(ddBtn, 1, T.Border)

				local ddVal = newLabel(ddBtn, {
					Position       = UDim2.new(0, 10, 0, 0),
					Size           = UDim2.new(1, -28, 1, 0),
					TextSize       = 12,
					TextColor3     = T.TextSub,
					TextXAlignment = Enum.TextXAlignment.Left,
					Font           = Enum.Font.Gotham,
					ZIndex         = 7,
				})

				local caretLbl = newLabel(ddBtn, {
					AnchorPoint    = Vector2.new(1, 0.5),
					Position       = UDim2.new(1, -8, 0.5, 0),
					Size           = UDim2.new(0, 16, 0, 16),
					Text           = "▾",
					TextSize       = 14,
					TextColor3     = T.TextSub,
					ZIndex         = 7,
				})

				-- Selected state
				local selected: {[string]: boolean} = {}
				if default then
					if type(default) == "table" then
						for _, v in ipairs(default) do selected[v] = true end
					else
						selected[tostring(default)] = true
					end
				end

				local function updateLabel()
					local parts = {}
					for _, opt in ipairs(options) do
						if selected[opt] then parts[#parts+1] = opt end
					end
					if #parts == 0 then
						ddVal.Text      = "None"
						ddVal.TextColor3= T.TextHint
					elseif #parts == #options and multi then
						ddVal.Text      = "All selected"
						ddVal.TextColor3= T.TextSub
					elseif #parts == 1 then
						ddVal.Text      = parts[1]
						ddVal.TextColor3= T.Text
					else
						ddVal.Text      = #parts .. " selected"
						ddVal.TextColor3= T.Text
					end
				end

				updateLabel()

				-- Menu (opens below)
				local menuOpen = false
				local menu: ScrollingFrame?

				local function closeMenu()
					if menu then menu:Destroy(); menu = nil end
					menuOpen = false
					tween(caretLbl, 0.1, { Rotation = 0 })
				end

				local function openMenu()
					if menuOpen then closeMenu(); return end
					menuOpen = true
					tween(caretLbl, 0.1, { Rotation = 180 })

					local m = Instance.new("ScrollingFrame")
					m.Name                   = "DDMenu"
					m.AnchorPoint            = Vector2.new(0, 0)
					m.Position               = UDim2.new(0, ddBtn.AbsolutePosition.X - win.AbsolutePosition.X,
					                                      0, ddBtn.AbsolutePosition.Y - win.AbsolutePosition.Y + ddBtn.AbsoluteSize.Y + 2)
					m.Size                   = UDim2.new(0, PILL_W, 0, math.min(#options * 32, 160))
					m.BackgroundColor3       = T.Surface
					m.BackgroundTransparency = 0.02
					m.ScrollBarThickness     = 3
					m.ScrollBarImageColor3   = T.Accent
					m.CanvasSize             = UDim2.new(0, 0, 0, 0)
					m.AutomaticCanvasSize    = Enum.AutomaticSize.Y
					m.ZIndex                 = 20
					m.Parent                 = win
					corner(m, 6)
					stroke(m, 1, T.Border)
					listLayout(m, Enum.FillDirection.Vertical, 0)
					menu = m

					for _, opt in ipairs(options) do
						local optBtn = newButton(m, {
							Size             = UDim2.new(1, 0, 0, 32),
							BackgroundColor3 = selected[opt] and T.SurfaceHi or T.Surface,
							BackgroundTransparency = selected[opt] and 0 or 1,
							ZIndex           = 21,
						})

						local tickLbl = newLabel(optBtn, {
							Position  = UDim2.new(0, 6, 0, 0),
							Size      = UDim2.new(0, 18, 1, 0),
							Text      = selected[opt] and "✓" or "",
							TextSize  = 13,
							TextColor3= T.On,
							ZIndex    = 22,
						})

						local optLbl = newLabel(optBtn, {
							Position       = UDim2.new(0, 26, 0, 0),
							Size           = UDim2.new(1, -30, 1, 0),
							Text           = opt,
							TextSize       = 13,
							Font           = Enum.Font.Gotham,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex         = 22,
						})

						optBtn.MouseEnter:Connect(function()
							if not selected[opt] then
								tween(optBtn, 0.08, { BackgroundTransparency = 0.4 })
								optBtn.BackgroundColor3 = T.SurfaceHi
							end
						end)
						optBtn.MouseLeave:Connect(function()
							if not selected[opt] then
								tween(optBtn, 0.08, { BackgroundTransparency = 1 })
							end
						end)

						optBtn.MouseButton1Click:Connect(function()
							if not multi then
								for k in pairs(selected) do selected[k] = false end
							end
							selected[opt] = not selected[opt]
							tickLbl.Text = selected[opt] and "✓" or ""
							tween(optBtn, 0.08, {
								BackgroundTransparency = selected[opt] and 0 or 1,
								BackgroundColor3 = T.SurfaceHi
							})
							updateLabel()
							if callback then
								if multi then
									local vals = {}
									for _, o in ipairs(options) do
										if selected[o] then vals[#vals+1] = o end
									end
									pcall(callback, vals)
								else
									for _, o in ipairs(options) do
										if selected[o] then pcall(callback, o); break end
									end
								end
							end
							if not multi then closeMenu() end
						end)
					end
				end

				ddBtn.MouseButton1Click:Connect(openMenu)

				-- Close menu on outside click
				UserInputService.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 and menuOpen then
						task.wait()   -- let button click process first
						local pos = inp.Position
						if menu then
							local ap = menu.AbsolutePosition
							local as = menu.AbsoluteSize
							local inMenu = pos.X >= ap.X and pos.X <= ap.X + as.X
								and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
							if not inMenu then closeMenu() end
						end
					end
				end)

				local ctrl = {}
				ctrl._row  = row
				ctrl._name = name2
				function ctrl:Get()
					if multi then
						local r = {}
						for _, o in ipairs(options) do if selected[o] then r[#r+1] = o end end
						return r
					else
						for _, o in ipairs(options) do if selected[o] then return o end end
						return nil
					end
				end
				function ctrl:Set(v)
					for k in pairs(selected) do selected[k] = false end
					if type(v) == "table" then
						for _, val in ipairs(v) do selected[val] = true end
					elseif v then
						selected[tostring(v)] = true
					end
					updateLabel()
				end
				function ctrl:SetOptions(opts: {string})
					options = opts
					for k in pairs(selected) do
						local found = false
						for _, o in ipairs(opts) do if o == k then found = true break end end
						if not found then selected[k] = nil end
					end
					updateLabel()
				end
				function ctrl:Destroy() row:Destroy() end
				function ctrl:SetVisible(v: boolean) row.Visible = v end

				table.insert(Window._allElements, ctrl)
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── BUTTON ───────────────────────────────────────────────────────
			function Section:Button(cfg2: {[string]: any})
				cfg2 = cfg2 or {}
				local name2    = cfg2.Name     or "Button"
				local btnText  = cfg2.Text     or name2
				local callback = cfg2.Callback

				local row = makeRow(name2, 44)
				rowLabel(row, name2, 12, 0, 220)

				local btn = newButton(row, {
					AnchorPoint      = Vector2.new(1, 0.5),
					Position         = UDim2.new(1, -10, 0.5, 0),
					Size             = UDim2.new(0, 100, 0, 28),
					BackgroundColor3 = T.Accent,
					BackgroundTransparency = 0,
					Text             = btnText,
					TextSize         = 13,
					TextColor3       = T.Text,
					ZIndex           = 6,
				})
				corner(btn, 6)
				stroke(btn, 1, T.AccentDark)
				grad(btn, T.Accent, T.AccentDark, 90)

				btn.MouseEnter:Connect(function()
					tween(btn, 0.1, { BackgroundColor3 = T.AccentLight })
				end)
				btn.MouseLeave:Connect(function()
					tween(btn, 0.1, { BackgroundColor3 = T.Accent })
				end)
				btn.MouseButton1Click:Connect(function()
					if callback then pcall(callback) end
				end)

				local ctrl = {}
				ctrl._row  = row
				ctrl._name = name2
				function ctrl:Press() if callback then pcall(callback) end end
				function ctrl:Destroy() row:Destroy() end
				function ctrl:SetVisible(v: boolean) row.Visible = v end

				table.insert(Window._allElements, ctrl)
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── INPUT ────────────────────────────────────────────────────────
			function Section:Input(cfg2: {[string]: any})
				cfg2 = cfg2 or {}
				local name2      = cfg2.Name        or "Input"
				local placeholder= cfg2.Placeholder or ""
				local default2   = cfg2.Default     or ""
				local callback   = cfg2.Callback
				local numericOnly= cfg2.Numeric      or false

				local row = makeRow(name2, 44)
				rowLabel(row, name2, 12, 0, 180)

				local inputWrap = Instance.new("Frame")
				inputWrap.AnchorPoint           = Vector2.new(1, 0.5)
				inputWrap.Position              = UDim2.new(1, -10, 0.5, 0)
				inputWrap.Size                  = UDim2.new(0, 150, 0, 28)
				inputWrap.BackgroundColor3      = T.SurfaceHi
				inputWrap.BackgroundTransparency= 0
				inputWrap.ZIndex                = 6
				inputWrap.Parent                = row
				corner(inputWrap, 6)
				stroke(inputWrap, 1, T.Border)

				local tb = Instance.new("TextBox")
				tb.Size             = UDim2.new(1, -16, 1, 0)
				tb.Position         = UDim2.new(0, 8, 0, 0)
				tb.BackgroundTransparency = 1
				tb.Text             = default2
				tb.PlaceholderText  = placeholder
				tb.PlaceholderColor3= T.TextHint
				tb.TextColor3       = T.Text
				tb.Font             = Enum.Font.Gotham
				tb.TextSize         = 13
				tb.TextXAlignment   = Enum.TextXAlignment.Left
				tb.ClearTextOnFocus = false
				tb.ZIndex           = 7
				tb.Parent           = inputWrap

				tb.FocusLost:Connect(function(enter)
					if enter then
						local v = tb.Text
						if numericOnly then
							v = tostring(tonumber(v) or 0)
							tb.Text = v
						end
						if callback then pcall(callback, v) end
					end
				end)

				local ctrl = {}
				ctrl._row  = row
				ctrl._name = name2
				function ctrl:Get(): string return tb.Text end
				function ctrl:Set(v: string) tb.Text = tostring(v) end
				function ctrl:Destroy() row:Destroy() end
				function ctrl:SetVisible(v: boolean) row.Visible = v end

				table.insert(Window._allElements, ctrl)
				table.insert(Section._elements, ctrl)
				return ctrl
			end

			-- ── LABEL ────────────────────────────────────────────────────────
			function Section:Label(cfg2: {[string]: any})
				cfg2 = cfg2 or {}
				local text = cfg2.Text or ""

				local row = makeRow("_lbl", 36)
				local lbl = newLabel(row, {
					Position       = UDim2.new(0, 12, 0, 0),
					Size           = UDim2.new(1, -24, 1, 0),
					Text           = text,
					TextSize       = 13,
					TextColor3     = T.TextSub,
					Font           = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex         = 6,
				})

				local ctrl = {}
				ctrl._row  = row
				ctrl._name = text
				function ctrl:Set(v: string) lbl.Text = v end
				function ctrl:Get(): string return lbl.Text end
				function ctrl:Destroy() row:Destroy() end
				function ctrl:SetVisible(v: boolean) row.Visible = v end

				table.insert(Window._allElements, ctrl)
				return ctrl
			end

			return Section
		end

		-- First tab auto-activates
		if #Window._tabs == 0 then
			task.defer(activate)
		end

		table.insert(Window._tabs, Tab)
		return Tab
	end

	-- ── Search ────────────────────────────────────────────────────────────────
	local function applySearch(query: string)
		query = query:lower()
		for _, el in ipairs(Window._allElements) do
			if el._row and el._name then
				local match = query == "" or el._name:lower():find(query, 1, true) ~= nil
				el._row.Visible = match
			end
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		applySearch(searchBox.Text)
	end)

	function Window:Search(query: string)
		searchBox.Text = query
		applySearch(query)
	end

	function Window:Destroy()
		gui:Destroy()
	end

	function Window:Toggle()
		win.Visible = not win.Visible
	end

	return Window
end

-- ────────────────────────────────────────────────────────────────────────────
--  Public API
-- ────────────────────────────────────────────────────────────────────────────
local EmberUI = {}

function EmberUI:Window(cfg: {[string]: any}?)
	return buildWindow(cfg or {})
end

EmberUI.State = State

return EmberUI
