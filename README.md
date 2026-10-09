# EmberUI

A high-quality, single-file Roblox UI library with a warm, polished aesthetic.

## Features

- **Window** — draggable, closeable, resizable hint
- **Tabs** — left-sidebar navigation with animated active state
- **Side buttons** — right-sidebar utility buttons (Discord, Settings, etc.)
- **Sections** — collapsible option groups with chevron indicator
- **Elements**
  - **Toggle** — animated pill switch with ON/OFF gradient
  - **Slider** — draggable track with fill bar + value label
  - **Dropdown** — single or multi-select with live search menu
  - **Button** — accent-styled with hover effect
  - **Input** — text/numeric input field
  - **Label** — static or updateable text row
- **Search** — bottom bar filters all elements by name live
- **State** — reactive value container with subscriptions, bindable to toggles

## Quick Start

```lua
local EmberUI = require(game.ReplicatedStorage.EmberUI)

local Win = EmberUI:Window({ Title = "My Hub" })

Win:SideButton("Discord", function() end)

local Tab = Win:Tab("Farm")
local Sec = Tab:Section("Auto Steal")

local tog = Sec:Toggle({
    Name     = "Auto Steal",
    Default  = false,
    Callback = function(v) print(v) end,
})

Sec:Slider({ Name = "Speed", Min = 1, Max = 200, Default = 16, Suffix = " WS" })
Sec:Dropdown({ Name = "Areas", Options = {"A","B","C"}, Multi = true })
Sec:Button({ Name = "Teleport", Text = "Go", Callback = function() end })
Sec:Input({ Name = "Value", Placeholder = "0..100" })
```

## State System

```lua
local s = EmberUI.State(false)
s:Sub(function(v) print("changed:", v) end)
tog:Bind(s)   -- toggle drives state and vice-versa
```

## Rojo Setup

```
rojo serve default.project.json
```

Place `EmberUI.lua` in `ReplicatedStorage` and `Demo.client.luau` in `StarterPlayerScripts`.

## License

MIT
