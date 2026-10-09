# Testing EmberUI

Run every automated check from the repository root:

```powershell
./scripts/test.ps1
```

The script runs every `tests/Unit/*.spec.luau` test and builds the Rojo project to validate source-tree and module links. To perform only the build:

```powershell
& $env:ROJO_BIN build default.project.json --output EmberUI.rbxlx
```

Interaction behavior—touch, gamepad, resizing, overlay positioning, and visual theme review—must also be exercised in Roblox Studio because the standalone Luau runtime does not provide Roblox services or GUI rendering.
