# EmberUI architecture

EmberUI is packaged as `src/EmberUI`, with `init.lua` as the public ModuleScript required from `ReplicatedStorage`. `App/Library.lua` composes the current public API from its sibling systems.

## Ownership

Every window creates a `Core/Maid` scope. The scope owns its root `ScreenGui`, global input connections for dragging, resizing, sliders, key capture, the window overlay manager, and notifications created through that window. Calling `Window:Destroy()` is idempotent and destroys this scope.

Controls own their state subscriptions and release their stable window-local ID when destroyed. This allows a replacement control to reuse an ID after teardown.

## Shared systems

- `Core/State` provides subscriptions, one-shot listeners, derived values, and batched notifications.
- `Core/Signal` supplies component `Changed` subscriptions.
- `Managers/WindowManager` provides focus ordering and singleton windows.
- `Managers/OverlayManager` enforces one top-level dismissible overlay per window.
- `Managers/ThemeManager` remaps semantic token colours in active registered windows.
- `Managers/PersistenceManager` handles schema versions, migrations, defaults, and adapter-based storage.

## Public IDs

`Window({ Id = "settings" })` gives a singleton window by default. Component `Id` values are unique only within their containing window and are never derived from visible text.
