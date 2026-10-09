# EmberUI v2 API audit

Audited against `src/EmberUI.lua` on 2026-10-09.

| Public surface | Current behaviour | v3 disposition |
| --- | --- | --- |
| `EmberUI:Window(config)` | Creates one fixed-size draggable window | Keep with migration to a managed window API |
| `Window:Tab(name)` | Adds a sidebar tab | Keep |
| `Tab:Section(name, expanded?)` | Adds a collapsible section | Keep |
| `Section:Toggle(config)` | Boolean control; supports `Bind(State)` | Keep with shared handle contract |
| `Section:Slider(config)` | Mouse-driven number control | Redesign; retain basic config names |
| `Section:Dropdown(config)` | Single/multi select popup | Redesign; documented live search does not exist |
| `Section:Button(config)` | Click callback | Keep |
| `Section:Input(config)` | Text/numeric field, commits on Enter | Keep with migration |
| `Section:Label(config)` | Static/updateable text | Keep |
| `Section:Keybind(config)` | Keyboard capture | Redesign |
| `Window:SideButton(name, callback)` | Right-sidebar button | Keep with migration |
| `Window:Notify(config)` | Global toast | Redesign under NotificationManager |
| `Window:Search(query)` | Filters element rows by name | Keep |
| `Window:Minimize()` / `Toggle()` / `Destroy()` | Basic window actions | Keep; expand lifecycle semantics |
| `EmberUI.State(default)` | `Get`, `Set`, `Sub` | Redesign around `Subscribe`; retain `Sub` adapter |

## Confirmed gaps

- Window sizing is fixed; no resize implementation exists.
- Dropdowns do not have a search field or virtualisation.
- Mouse is the only complete interaction path.
- No public `Changed`, `SetDisabled`, or uniform stateful handle contract exists.
- v2 previously placed long-lived input listeners outside a lifecycle owner. The Phase 2 hotfix starts correcting this at window scope.
- The library used executor/CoreGui fallbacks. The hotfix now mounts only to `PlayerGui`.

## Supported v2 platform baseline

Roblox client UI mounted through `Players.LocalPlayer.PlayerGui`; desktop mouse is the currently verified interaction mode. Touch, keyboard, gamepad, responsive breakpoints, and persistence are v3 work and are not advertised as implemented.
