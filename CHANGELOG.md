# EmberUI Changelog

## v3 — Audit fix series (2026-10-09 → 2026-10-10)

Four passes addressing a full dual-audit of `src/EmberUI/App/Library.lua` and `EmberUI.lua`.
Sync enforced by `scripts/check-bundle-sync.ps1` (32 checks).

---

### Pass 1 — Renderer correctness

Commits: `1507164` and prior session.

| Item | Fix |
|---|---|
| C1 — `corner()` hardcodes 0 | `c.CornerRadius = UDim.new(0, r or 0)` |
| F4 partial — `getRoot()` | Full chain: `gethui()` → CoreGui → PlayerGui |
| H2 — toggle hardcoded green | `track.BackgroundColor3 = T.On`; gradient via `redGrad` |
| C4 — active tab indistinguishable | Active tab: `T.Accent` stroke; inactive: `T.Border` |
| H1 partial — chevron text char | Two rotated `Frame` instances (±45°); no text |
| F5 — popup in win | Dedicated `ScreenGui` at `DisplayOrder=100`; absolute screen coords |
| H5 — slider corners explicit 0 | `corner(trackBg,3)`, `corner(trackFill,3)`, `corner(handle,7)` |
| H6 — `redGrad` hardcoded white/black | `ColorSequence.new(T.AccentBright, T.AccentDark)` |
| C3 partial — tab hover invisible | `MouseEnter`/`MouseLeave` tween `tabHov` transparency |
| — | Drag gesture closes the top overlay on drag start |

---

### Pass 2 — Element API fixes

Commit: `6d6f864`.

| Item | Fix |
|---|---|
| H1 — dropdown tick was `"*"` | 8×8 `Frame` with `T.On`; `row._tick.Visible` toggled by selection |
| F3 — dropdown options not strings | `tostring()` on ingestion; `closeMenu()` on `SetOptions` |
| B1 partial — `FocusLost` needs enter | `tb.FocusLost:Connect(function()` — no enter parameter |
| B5 — `ImageList` no validation | `cols = math.max(1,…)`, `imgPx = math.max(8,…)` |
| F2 — `Label` clips long text | `AutomaticSize.Y` + `TextWrapped = true`; row height 0 |
| F1 — Separator/Spacer not in `_elements` | `table.insert(Section._elements, ctrl)` for both |
| F1 — search hides empty-element sections | `sec._wrap.Visible = any or #sec._elements == 0` |

---

### Pass 3 — Theme completeness + API contract

Commit: `8781d4c`.

| Item | Fix |
|---|---|
| H3 — rows hardcode black | `T.Surface` / `T.SurfaceHi` for row backgrounds |
| R3 — theme switching incomplete | Toggle off: `T.SurfaceHover`/`T.OffDark`; on: `T.OnBright` |
| R3 — slider ignores theme | Fill `T.Accent` via `redGrad`; handle highlight `T.AccentBright` |
| R3 — textStroke hardcodes black | `s.Color = T.Border` |
| M2 — EmberLight 8 of 27 tokens | Full 27-token EmberLight; synced to bundle |
| B4 — duplicate Id throws | `_validateControlId` returns existing control; all 11 callers updated |
| R1 partial — no viewport awareness | `clampToViewport()` auto-scales and clamps position on resize |
| M5 — no sync enforcement | `scripts/check-bundle-sync.ps1` added (24 checks at this point) |

---

### Pass 4 — Remaining audit items + responsive reflow

Commits: `4d1c3ae`, `e42f172`, `e5f09fc`.

| Item | Fix |
|---|---|
| F4 — `protect_gui` missing | `pcall(protect_gui, gui)` called **before** `gui.Parent` |
| B1 — numeric input no live filter | `GetPropertyChangedSignal("Text")` strips non-numeric chars while typing |
| B3 — README "constrained-resizable" lie | 14×14 resize handle added (bottom-right); min 300×200; UIScale-corrected delta |
| B3 — README corrected | Removed false claim; documents mount order and resize accurately |
| R2 — text muddy at small sizes | Sub-labels 11→12 px; `textStroke` transparency 0.25→0.5 |
| H1 — minimize/close ASCII | Minimize: `string.char(0xe2,0x80,0x93)` (en-dash); close: `string.char(0xc3,0x97)` (×) |
| M4 — minimize hyphen | Same as H1 — en-dash sequence |
| M3 — notification tween no-op | Verified not a no-op: 332 px horizontal slide at TI_MED (220 ms) |
| R1 — breakpoint fires but no reflow | `reflowSidebar(bp)`: Compact (<520 px) narrows sidebar 158→52 px, hides tab labels; Standard/Wide restores both |
| — | `Tab._lbl` stored on tab handle; reflow iterates `Window._tabs` |
| — | `v2-audit.md` updated: stale gaps struck out, remaining v3 work documented |
| — | Sync script expanded to 32 checks covering all Pass 4 items |

---

### B4 code ↔ guide.md verification

`guide.md:84` states: *"When set, calling the same constructor again with the same `Id` returns the existing control instead of creating a duplicate."*

`Library.lua:629–638` (`_validateControlId`): checks `self._ids[id]`; returns the stored control on a match. Every constructor (Toggle, Slider, Dropdown, Button, Input, Label, Separator, Spacer, Progress, Keybind, ImageList) calls `_validateControlId` first and early-returns the result. `_registerControl` stores `self._ids[id] = ctrl` on first creation. Code and docs match exactly.

---

### Testing note

No Roblox Studio instance was connected during this session. All verification is static: file reads, `Grep` pattern checks, and `scripts/check-bundle-sync.ps1` (32/32 pass). Runtime behavior requires loading `EmberUI.lua` in a Roblox executor or `src/EmberUI` via Rojo in Studio.
