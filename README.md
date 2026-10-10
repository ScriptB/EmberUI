# EmberUI

A modular Roblox UI library with a warm, polished aesthetic.

## Features

- **Window** — draggable, closeable, minimisable, and constrained-resizable
- **Tabs** — left-sidebar navigation with animated active state
- **Side buttons** — right-sidebar utility buttons (Discord, Settings, etc.)
- **Sections** — collapsible option groups with chevron indicator
- **Elements**
  - **Toggle** — animated pill switch with ON/OFF gradient
  - **Slider** — draggable track with fill bar + value label
  - **Dropdown** — single or multi-select with option search
  - **Button** — accent-styled with hover effect
  - **Input** — text/numeric input field
  - **Label** — static or updateable text row
  - **Keybind** — keyboard capture
  - **Layout** — separator and spacer primitives
  - **Progress** — token-styled progress feedback
- **Search** — bottom bar filters all elements by name live
- **State** — reactive value container with subscriptions, bindable to toggles

## Current support

EmberUI mounts via `gethui()` → CoreGui → PlayerGui (in that order) and calls `protect_gui` when available. Mouse, touch, and basic gamepad/keyboard input are supported through Roblox `Activated` controls. Dropdown option search and drag-to-resize (bottom-right corner handle, minimum 300×200) are available. Virtualised large lists, complete keyboard/gamepad navigation, responsive page reflow, and persistence remain v3 work in progress.

## Themes

Switch the built-in semantic-token themes at runtime:

```lua
EmberUI:SetTheme("Ember Light")
EmberUI:SetTheme("Ember High Contrast")
```

For accessibility preferences, use `EmberUI:SetReducedMotion(true)` and `window:SetScale(1.25)`.

## Persistence

`EmberUI.PersistenceManager` provides versioned schema migration over a supplied read/write adapter. `MemoryAdapter()` is suitable for previews and tests; production experiences should provide a server-backed adapter.

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
aftman install
rojo serve default.project.json
```

The tracked `aftman.toml` pins Rojo 7.7.1. Rojo maps the `src/EmberUI` package into `ReplicatedStorage` and the demo into `StarterPlayerScripts`; `init.lua` is the public ModuleScript and `App/Library.lua` is its composition layer. See the [architecture](docs/architecture.md) and [testing](docs/testing.md) guides for lifecycle and validation details.

## License

MIT
