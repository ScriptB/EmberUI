# EmberUI Changelog

## v3 — Audit fix series (2026-10-09 → 2026-10-10)

Four distinct passes across commits `1507164`, `6d6f864`, `8781d4c`, `4d1c3ae`, `e42f172`, and the current pass.

---

### Pass 1 — Renderer correctness (`1507164` + prior)

- `corner()` — radius was hardcoded to 0; now uses `r or 0`.
- `getRoot()` — full executor fallback chain: `gethui()` → CoreGui → PlayerGui.
- Toggle pill — uses `T.On` gradient (was hardcoded green `Color3.fromRGB(58,255,55)`).
- Active tab stroke — `T.Accent`; inactive tabs use `T.Border`.
- Section chevron — two rotated `Frame` instances (±45°); no text characters.
- Dropdown popup — dedicated `ScreenGui` at `DisplayOrder=100`; absolute screen coordinates avoid UIScale interference.
- Slider corners — 3/3/7 px on track/fill/handle.
- `redGrad` — uses `T.AccentBright` / `T.AccentDark`; no hardcoded white/black.
- Drag gesture — closes the top overlay on drag start.

---

### Pass 2 — Element API fixes (`6d6f864`)

- Dropdown tick — 8×8 `Frame` with `T.On`; `row._tick.Visible` toggled by selection state.
- `SetOptions` — coerces all entries to string; calls `closeMenu()` first.
- `Input.FocusLost` — always fires callback (was conditional on `enter` parameter).
- `ImageList` — `Columns` clamped to ≥ 1; `ImageSize` clamped to ≥ 8.
- `Label` — `AutomaticSize.Y` + `TextWrapped = true`; row height 0 (auto-sized).
- Separator / Spacer — registered in `_elements` so search visibility works.
- Search — shows sections that have zero elements (previously hid them unconditionally).

---

### Pass 3 — Theme completeness + API contract (`8781d4c`)

- `textStroke` — uses `T.Border` (was hardcoded black).
- Toggle — off-track `T.SurfaceHover`, off-knob `T.OffDark`, on-knob `T.OnBright`.
- Slider — fill `T.Accent` via `redGrad`, drag highlight `T.AccentBright`.
- Top-bar — base color `T.Accent`.
- EmberLight — 27 semantic tokens covering `On/Off/Success/Warn/Error/Info` families; synced to bundle.
- `_validateControlId` (B4) — returns existing control on duplicate Id instead of throwing.
- Viewport auto-scale — `clampToViewport()` scales window down when it would overflow the viewport.
- Sync script — `scripts/check-bundle-sync.ps1` with 24 pattern checks added.

---

### Pass 4 — Remaining audit items (`4d1c3ae`, `e42f172`)

- `protect_gui` (F4) — called via `pcall` **before** `gui.Parent` assignment; required by some executors.
- Numeric input live filter (B1) — `GetPropertyChangedSignal("Text")` strips non-numeric characters while typing.
- Resize handle (B3) — 14×14 bottom-right `Frame`; minimum 300×200; UIScale-corrected (`delta / uiScale.Scale`).
- Text readability (R2) — sub-labels 11→12 px; `textStroke` transparency 0.25→0.5.
- README — removed false "constrained-resizable" claim; now accurately describes mount order and resize.
- Sync script — expanded to 29 checks covering all Pass 4 items.

---

### Pass 5 — Responsive reflow + doc accuracy (current)

- Sidebar collapse reflow (R1) — `reflowSidebar(bp)` fires on every breakpoint transition. At `Compact` (window width < 520 px) the left sidebar narrows from 158 px to 52 px and tab labels hide; `Standard`/`Wide` restores both. `Tab._lbl` stored on the tab handle so the reflow can reach it.
- `v2-audit.md` — updated to strike out resolved gaps and record remaining v3 work; no longer lists resize as missing or mount order as wrong.
- Sync script — 3 new checks for `reflowSidebar`, `COMPACT_SIDEBAR_W`, and `Tab._lbl`.

---

## Notes on verification

No Roblox Studio runtime is available in this environment. All verification is static: file reads, `Grep`/`PowerShell` pattern checks, and the `scripts/check-bundle-sync.ps1` script (32 checks as of Pass 5). Runtime testing requires loading `EmberUI.lua` in a Roblox executor or `src/EmberUI` via Rojo in Studio.
