# Migrating from EmberUI v2 to v3

The current hotfix preserves existing window, tab, section, and control calls. Start assigning a stable `Id` to controls now:

```lua
section:Toggle({
    Id = "auto-steal",
    Name = "Auto Steal",
    Default = false,
})
```

IDs must be unique within a window. Duplicate IDs now raise an actionable error. Slider bounds must be numbers with `Min < Max`; `Decimals` must be an integer between 0 and 6.

The README no longer claims resize or dropdown search support. Those capabilities will arrive only with their shared v3 systems.
