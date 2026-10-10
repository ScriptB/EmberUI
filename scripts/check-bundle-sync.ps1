$ErrorActionPreference = "Stop"

# Checks that key source files are mirrored correctly in EmberUI.lua (the executor bundle).
# Run this before committing or after editing source files.

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$bundle = Join-Path $root "EmberUI.lua"
$bundleBytes = [System.IO.File]::ReadAllBytes($bundle)
if ($bundleBytes.Length -ge 3 -and $bundleBytes[0] -eq 0xEF -and $bundleBytes[1] -eq 0xBB -and $bundleBytes[2] -eq 0xBF) {
    Write-Error "BUNDLE OUT OF SYNC: EmberUI.lua must not start with a UTF-8 BOM; executor loadstring() rejects U+FEFF."
    exit 1
}
$bundleContent = Get-Content $bundle -Raw -Encoding UTF8

$failures = 0

function Check-Signature($label, $pattern) {
    if (-not ($bundleContent -match [regex]::Escape($pattern))) {
        Write-Warning "BUNDLE OUT OF SYNC: $label"
        Write-Warning "  Expected to find: $pattern"
        $script:failures++
    } else {
        Write-Host "OK  $label"
    }
}

# Theme tokens — EmberLight must have all fields
Check-Signature "EmberLight.Accent"       'Accent       = Color3.fromRGB(190, 20, 20)'
Check-Signature "EmberLight.On"           'On           = Color3.fromRGB(30, 130, 45)'
Check-Signature "EmberLight.Success"      'Success      = Color3.fromRGB(30, 130, 45)'
Check-Signature "EmberLight.Warn"         'Warn         = Color3.fromRGB(180, 120, 15)'
Check-Signature "EmberLight.Error"        'Error        = Color3.fromRGB(195, 35, 35)'
Check-Signature "EmberLight.Info"         'Info         = Color3.fromRGB(30, 100, 185)'

# Library fixes
Check-Signature "corner() radius fix"     'c.CornerRadius = UDim.new(0, r or 0)'
Check-Signature "getRoot gethui"          'gethui'
Check-Signature "toggle T.On"             'track.BackgroundColor3 = T.On'
Check-Signature "toggle T.SurfaceHover"   'track.BackgroundColor3 = T.SurfaceHover'
Check-Signature "toggle T.OffDark knob"   'BackgroundColor3 = T.OffDark'
Check-Signature "slider T.Accent fill"    'trackFill.BackgroundColor3 = T.Accent'
Check-Signature "slider T.AccentBright"   'BackgroundColor3 = T.AccentBright }'
Check-Signature "textStroke T.Border"     's.Color        = T.Border'
Check-Signature "popup ScreenGui"         'popupGui'
Check-Signature "dropdown tick Frame"     'tick.BackgroundColor3 = T.On'
Check-Signature "tick Visible flag"       'row._tick.Visible = selected[opt] == true'
Check-Signature "SetOptions closeMenu"    'closeMenu()'
Check-Signature "FocusLost no enter"      'tb.FocusLost:Connect(function()'
Check-Signature "Label AutomaticSize"     'AutomaticSize  = Enum.AutomaticSize.Y,'
Check-Signature "Label TextWrapped"       'TextWrapped    = true,'
Check-Signature "Label Name option"       'Validation.warnUnknown(c2, { "Id", "Name", "Text", "Visible" }, "Label")'
Check-Signature "search empty-section"   'sec._wrap.Visible = any or #sec._elements == 0'
Check-Signature "duplicate Id returns"    'return self._ids[id]'
Check-Signature "viewport auto-scale"     '(viewport.X * 0.92) / win.Size.X.Offset'
Check-Signature "protect_gui call"        'if type(protect_gui) == "function" then pcall(protect_gui, gui) end'
Check-Signature "resize handle"           'ResizeHandle'
Check-Signature "resize min clamp"        'MIN_W, MIN_H = 300, 200'
Check-Signature "B1 numeric live filter" 'GetPropertyChangedSignal("Text"):Connect'
Check-Signature "R2 textStroke 0.5"       's.Transparency = 0.5'
Check-Signature "R1 reflowSidebar fn"     'local function reflowSidebar(bp)'
Check-Signature "R1 compact sidebar"      'COMPACT_SIDEBAR_W = 52'
Check-Signature "R1 tab._lbl stored"      'Tab._lbl = lbl'
Check-Signature "protect_gui notifGui"    'if type(protect_gui) == "function" then pcall(protect_gui, g) end'
Check-Signature "protect_gui popupGui"    'if type(protect_gui) == "function" then pcall(protect_gui, popupGui) end'
Check-Signature "notif _notifs cleanup"   'ownerMaid:Give(function()'
Check-Signature "FileAdapter function"    'function PersistenceManager.FileAdapter(prefix)'
Check-Signature "FileAdapter readfile"    'if type(readfile) ~= "function" then return nil end'
Check-Signature "FileAdapter writefile"  'if type(writefile) ~= "function" then return end'
Check-Signature "SaveSettings function"  'function Window:SaveSettings()'
Check-Signature "LoadSettings function"  'function Window:LoadSettings(values)'
Check-Signature "Keybind MouseLeave SurfaceHi" 'if not listening then tw(kBtn, { BackgroundColor3 = T.SurfaceHi }) end'
Check-Signature "Keybind ctrl:Clear"     'function ctrl:Clear() setKey(Enum.KeyCode.Unknown) end'
Check-Signature "Keybind startListening" 'local function startListening()'
Check-Signature "Keybind _focusable"     'ctrl._focusable = true'
Check-Signature "Toggle _activate"       'function ctrl:_activate() if not disabled then applyToggle(not value) end end'
Check-Signature "Button _activate"       'function ctrl:_activate() self:Press() end'
Check-Signature "kbCycleFocus function"  'local function kbCycleFocus(delta)'
Check-Signature "kbActivateFocused"      'local function kbActivateFocused()'
Check-Signature "Tab key nav"            'inp.KeyCode == Enum.KeyCode.Tab then'
Check-Signature "Window:ClearFocus"      'function Window:ClearFocus() kbClearFocus() end'
Check-Signature "Gamepad isGamepad fn"   'local function isGamepad(ut)'
Check-Signature "Gamepad DPadDown nav"   'inp.KeyCode == Enum.KeyCode.DPadDown then'
Check-Signature "Gamepad ButtonA"        'inp.KeyCode == Enum.KeyCode.ButtonA then'
Check-Signature "Gamepad ButtonB clear"  'inp.KeyCode == Enum.KeyCode.ButtonB then'
Check-Signature "Tab._pageWide"          'Tab._pageWide = pageWide'
Check-Signature "Tab._sections"          'Tab._sections = {}'
Check-Signature "_reflowColumns fn"      'function Tab._reflowColumns(_, bp)'
Check-Signature "colLeft ColLeft"        'colLeft.Name = "ColLeft"'
Check-Signature "colRight ColRight"      'colRight.Name = "ColRight"'
Check-Signature "isWide helper"          'local function isWide(bp) return bp == "Wide" or bp == "Expanded" end'
Check-Signature "reflowSidebar calls reflowColumns" 'if tab._reflowColumns then tab._reflowColumns(bp) end'
Check-Signature "Section inserts into Tab._sections" 'table.insert(Tab._sections, secWrap)'

if ($failures -gt 0) {
    Write-Error "$failures sync check(s) failed. Edit EmberUI.lua to match the source files in src/."
    exit 1
} else {
    Write-Host "All sync checks passed -- bundle is in sync." -ForegroundColor Green
}
