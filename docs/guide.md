# EmberUI — Library Guide

## Setup

Place the `EmberUI` folder in `ReplicatedStorage` and require it from a `LocalScript`:

```lua
local EmberUI = require(game.ReplicatedStorage.EmberUI)
```

---

## Window

```lua
local Win = EmberUI:Window({
    Title     = "My Hub",     -- required
    Id        = "my-hub",     -- optional; enables Singleton behaviour
    Singleton = true,         -- default true when Id is set; reuses existing window
    Width     = 460,          -- default 460
    Height    = 360,          -- default 360
    Scale     = 1,            -- UIScale multiplier; default 1
})
```

### Window methods

| Method | Description |
|---|---|
| `Win:Destroy()` / `Win:Close()` | Remove window and clean up |
| `Win:IsDestroyed()` | Returns `true` after destroy |
| `Win:Minimize()` | Collapse to topbar |
| `Win:Restore()` | Expand if minimised |
| `Win:Toggle()` | Flip visibility |
| `Win:BringToFront()` | Raise above other windows |
| `Win:SetVisible(bool)` | Show / hide |
| `Win:SetPosition(UDim2)` | Reposition |
| `Win:GetPosition()` | Returns current `UDim2` position |
| `Win:SetSize(UDim2)` | Resize |
| `Win:GetSize()` | Returns current `UDim2` size |
| `Win:SetScale(number)` | Set `UIScale` |
| `Win:GetScale()` | Returns current scale |
| `Win:GetBreakpoint()` | Returns current layout breakpoint |
| `Win:BreakpointChanged(fn)` | Fires `fn(breakpoint)` on resize |
| `Win:Search(query)` | Programmatically filter the search box |

---

## SideButton

Renders a button in the right sidebar.

```lua
Win:SideButton("Discord", function()
    -- clicked
end)
```

---

## Tabs

```lua
local Farm = Win:Tab("Farm")
```

The first tab created is activated automatically. Each tab has an independent scrollable page.

---

## Sections

```lua
local Sec = Farm:Section("Auto Steal")          -- expanded by default
local Sec = Farm:Section("Advanced", false)     -- collapsed by default
```

All controls are added to a section.

---

## Controls

Every control constructor accepts an optional `Id` key. When set, calling the same constructor again with the same `Id` returns the existing control instead of creating a duplicate.

### Toggle

```lua
local tog = Sec:Toggle({
    Name     = "Auto Steal",
    Default  = false,
    Note     = "Optional sub-text below the label",
    Disabled = false,
    Callback = function(value) end,
})
```

| Method | Description |
|---|---|
| `tog:Get()` | Returns current `boolean` |
| `tog:Set(v, fire?)` | Set value; `fire=false` skips callback |
| `tog:Changed(fn)` | Subscribe; returns connection |
| `tog:SetDisabled(bool)` | Enable / disable interaction |
| `tog:SetNote(text)` | Update the note label at runtime |
| `tog:GetNote()` | Returns current note text |
| `tog:Bind(state)` | Two-way bind to an `EmberUI.State` |
| `tog:Unbind()` | Remove state binding |
| `tog:Destroy()` | Remove from UI |
| `tog:SetVisible(bool)` | Show / hide row |

---

### Slider

```lua
local spd = Sec:Slider({
    Name     = "Walk Speed",
    Min      = 16,
    Max      = 250,
    Default  = 16,
    Decimals = 0,           -- decimal places shown; default 0
    Suffix   = " WS",       -- appended to the value label
    Disabled = false,
    Callback = function(value) end,
})
```

| Method | Description |
|---|---|
| `spd:Get()` | Returns current number |
| `spd:Set(v, fire?)` | Set value |
| `spd:Changed(fn)` | Subscribe |
| `spd:SetDisabled(bool)` | Enable / disable |
| `spd:SetRange(min, max)` | Update min / max at runtime |
| `spd:Destroy()` | Remove |
| `spd:SetVisible(bool)` | Show / hide row |

---

### Dropdown

```lua
local area = Sec:Dropdown({
    Name     = "Target Areas",
    Options  = { "Field A", "Field B", "Field C" },
    Multi    = false,           -- true allows multiple selections
    Default  = {},              -- table for Multi, string for single
    Disabled = false,
    Callback = function(value) end,
    -- Multi=false: value is the selected string or nil
    -- Multi=true:  value is a table of selected strings
})
```

| Method | Description |
|---|---|
| `area:Get()` | Returns current selection |
| `area:Set(v, fire?)` | Set selection |
| `area:Changed(fn)` | Subscribe |
| `area:SetDisabled(bool)` | Enable / disable |
| `area:SetOptions(opts)` | Replace option list at runtime |
| `area:Destroy()` | Remove |
| `area:SetVisible(bool)` | Show / hide row |

---

### Button

```lua
local btn = Sec:Button({
    Name     = "Teleport",
    Text     = "Go",        -- label on the button; defaults to Name
    Disabled = false,
    Callback = function() end,
})
```

| Method | Description |
|---|---|
| `btn:Press()` | Trigger callback programmatically |
| `btn:SetText(text)` | Update button label |
| `btn:SetDisabled(bool)` | Enable / disable |
| `btn:Destroy()` | Remove |
| `btn:SetVisible(bool)` | Show / hide row |

---

### Input

```lua
local inp = Sec:Input({
    Name        = "Custom Value",
    Placeholder = "Enter number...",
    Default     = "",
    Numeric     = false,    -- true restricts to numbers only
    Disabled    = false,
    Callback    = function(value) end,  -- fires on focus-lost
})
```

| Method | Description |
|---|---|
| `inp:Get()` | Returns current string |
| `inp:Set(v, fire?)` | Set text |
| `inp:Changed(fn)` | Subscribe |
| `inp:SetDisabled(bool)` | Enable / disable |
| `inp:Destroy()` | Remove |
| `inp:SetVisible(bool)` | Show / hide row |

---

### Label

```lua
local lbl = Sec:Label({ Text = "Version 1.0" })
```

| Method | Description |
|---|---|
| `lbl:Get()` | Returns text |
| `lbl:Set(text)` | Update text |
| `lbl:Destroy()` | Remove |
| `lbl:SetVisible(bool)` | Show / hide row |

---

### Separator

Renders a thin horizontal rule.

```lua
Sec:Separator()
```

---

### Spacer

Renders empty vertical space.

```lua
Sec:Spacer({ Height = 8 })    -- Height optional; default 8
```

---

### Progress

```lua
local prog = Sec:Progress({
    Name  = "Setup",
    Value = 0,      -- 0–1
})

prog:Set(0.75)

prog:Changed(function(value)
    -- fires when value changes
end)
```

| Method | Description |
|---|---|
| `prog:Get()` | Returns current 0–1 value |
| `prog:Set(v, fire?)` | Set value |
| `prog:Changed(fn)` | Subscribe |
| `prog:Destroy()` | Remove |
| `prog:SetVisible(bool)` | Show / hide row |

---

### Keybind

```lua
local kb = Sec:Keybind({
    Name     = "Toggle Key",
    Default  = Enum.KeyCode.RightShift,
    Disabled = false,
    Callback = function(keyCode) end,
})
```

Click the button in-game to enter listening mode, then press a key to bind it. Click again to cancel.

| Method | Description |
|---|---|
| `kb:Get()` | Returns current `Enum.KeyCode` |
| `kb:Set(keyCode)` | Set programmatically |
| `kb:Changed(fn)` | Subscribe |
| `kb:SetDisabled(bool)` | Enable / disable |
| `kb:Destroy()` | Remove |
| `kb:SetVisible(bool)` | Show / hide row |

---

### ImageList

Renders a grid of `rbxassetid://` images with optional captions.

```lua
local gallery = Sec:ImageList({
    Name      = "Items",
    Columns   = 3,          -- default 3
    ImageSize = 58,         -- px per cell; default 58
    Items     = {
        { Id = "rbxassetid://123456", Name = "Sword" },
        { Id = "rbxassetid://789012", Name = "Shield" },
        "rbxassetid://345678",    -- plain string; no caption
    },
    Callback  = function(item) end,
    -- item is the original table or string passed in Items
})
```

| Method | Description |
|---|---|
| `gallery:Destroy()` | Remove |
| `gallery:SetVisible(bool)` | Show / hide row |

---

## State

`EmberUI.State` is a simple reactive value. Bind it to controls so multiple widgets stay in sync without manual wiring.

```lua
local godState = EmberUI.State(false)

-- Read / write
godState:Get()          -- false
godState:Set(true)

-- Subscribe
godState:Sub(function(value)
    print("changed:", value)
end)

-- Bind to a toggle (two-way)
toggle:Bind(godState)
toggle:Unbind()
```

---

## Notifications

```lua
Win:Notify({
    Title   = "Done",
    Message = "Script loaded.",
    Type    = "success",    -- "success" | "warn" | "error" | "info"
    Duration = 3,           -- seconds; optional
})
```

---

## Search

The search bar filters section rows by name in real-time. Sections with no visible rows are hidden automatically.

Trigger programmatically:

```lua
Win:Search("speed")
Win:Search("")        -- clear filter
```

---

## Persistence

`EmberUI.PersistenceManager` is exposed on the public API for advanced save/load flows. See `docs/v3-api-decisions.md` for details.
