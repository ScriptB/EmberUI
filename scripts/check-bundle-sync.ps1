$ErrorActionPreference = "Stop"

# Checks that key source files are mirrored correctly in EmberUI.lua (the executor bundle).
# Run this before committing or after editing source files.

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$bundle = Join-Path $root "EmberUI.lua"
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
Check-Signature "search empty-section"   'sec._wrap.Visible = any or #sec._elements == 0'
Check-Signature "duplicate Id returns"    'return self._ids[id]'
Check-Signature "viewport auto-scale"     '(viewport.X * 0.92) / win.Size.X.Offset'
Check-Signature "protect_gui call"        'if type(protect_gui) == "function" then pcall(protect_gui, gui) end'
Check-Signature "resize handle"           'ResizeHandle'
Check-Signature "resize min clamp"        'MIN_W, MIN_H = 300, 200'
Check-Signature "B1 numeric live filter" 'GetPropertyChangedSignal("Text"):Connect'
Check-Signature "R2 textStroke 0.5"       's.Transparency = 0.5'

if ($failures -gt 0) {
    Write-Error "$failures sync check(s) failed. Edit EmberUI.lua to match the source files in src/."
    exit 1
} else {
    Write-Host "All sync checks passed -- bundle is in sync." -ForegroundColor Green
}
