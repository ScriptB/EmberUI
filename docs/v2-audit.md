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

## Confirmed gaps (v2 baseline)

These were the known gaps at the v2 baseline. See CHANGELOG.md for v3 fix status.

- ~~Window sizing is fixed; no resize implementation exists.~~ Fixed in v3 (B3 — bottom-right drag handle, min 300×200, UIScale-corrected).
- Dropdown live search and virtualisation — search field added in v3; virtualisation remains v3 future work.
- Mouse is the only complete interaction path.
- ~~No public `Changed`, `SetDisabled`, or uniform stateful handle contract exists.~~ Partial: `Changed` and `SetVisible` added; `SetDisabled` on Toggle/Slider/Button/Input/Dropdown added in v3.
- Long-lived input listeners — corrected in v3 (all listeners registered through `windowMaid`).
- ~~Mount order: hotfix mounted only to `PlayerGui`.~~ v3 restores full chain: `gethui()` → CoreGui → PlayerGui, with `protect_gui` called before parenting.

## Remaining v3 work

- Keyboard and gamepad navigation throughout.
- Full page reflow (v3 adds sidebar collapse at Compact breakpoint; multi-column content reflow is future work).
- Persistence beyond the in-memory `MemoryAdapter`.
- Keybind redesign (current implementation is functional but not redesigned).

## Supported v3 platform baseline

Roblox client UI mounted through `gethui()` → CoreGui → PlayerGui with `protect_gui` when available. Desktop mouse and touch input supported. Responsive sidebar collapse fires at the Compact breakpoint (window width < 520 px). Keyboard/gamepad, full content reflow, and persistence remain future work.
