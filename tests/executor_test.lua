local SOURCE_URL = "https://raw.githubusercontent.com/ScriptB/EmberUI/main/EmberUI.lua"

local function load()
    if syn then return loadstring(game:HttpGet(SOURCE_URL))()
    elseif http then return loadstring(http.request({ Url = SOURCE_URL }).Body)()
    elseif request then return loadstring(request({ Url = SOURCE_URL }).Body)()
    else error("No HTTP function found (syn/http/request)") end
end

local ok, EmberUI = pcall(load)
if not ok then
    warn("[EmberUI test] Failed to load bundle: " .. tostring(EmberUI))
    return
end

local passed, failed = 0, 0
local function check(label, cond, got)
    if cond then
        print("[PASS] " .. label)
        passed += 1
    else
        warn("[FAIL] " .. label .. (got ~= nil and (" (got: " .. tostring(got) .. ")") or ""))
        failed += 1
    end
end

local win = EmberUI:Window({ Title = "EmberUI Test", Width = 700, Height = 520 })
check("Window created",               type(win) == "table")
check("Window.Tab exists",            type(win.Tab) == "function")
check("Window.Notify exists",         type(win.Notify) == "function")
check("GetBreakpoint returns string", type(win:GetBreakpoint()) == "string")
check("GetScale returns number",      type(win:GetScale()) == "number")

local tab = win:Tab("Controls")
check("Tab created",        type(tab) == "table")
check("Tab.Section exists", type(tab.Section) == "function")

local sec = tab:Section("General")
check("Section created",         type(sec) == "table")
check("Section.Toggle exists",   type(sec.Toggle) == "function")
check("Section.Button exists",   type(sec.Button) == "function")
check("Section.Slider exists",   type(sec.Slider) == "function")
check("Section.Dropdown exists", type(sec.Dropdown) == "function")
check("Section.Input exists",    type(sec.Input) == "function")
check("Section.Keybind exists",  type(sec.Keybind) == "function")
check("Section.Label exists",    type(sec.Label) == "function")

local fired = false
local tog = sec:Toggle({ Id = "myToggle", Name = "Test Toggle", Default = false, Callback = function(v)
    fired = true
end })
check("Toggle created",              type(tog) == "table")
check("Toggle.Get = false",          tog:Get() == false)
tog:Set(true)
check("Toggle.Set true",             tog:Get() == true)
tog:Set(false)
check("Toggle.Set false",            tog:Get() == false)
check("Toggle.Changed exists",       type(tog.Changed) == "function")
check("Toggle._focusable",           tog._focusable == true)
check("Toggle._activate exists",     type(tog._activate) == "function")

local sli = sec:Slider({ Id = "mySlider", Name = "Speed", Min = 0, Max = 100, Default = 50 })
check("Slider created",   type(sli) == "table")
check("Slider.Get = 50",  sli:Get() == 50)
sli:Set(75)
check("Slider.Set 75",    sli:Get() == 75)
sli:Set(200)
check("Slider clamped",   sli:Get() == 100)

local btnFired = false
local btn = sec:Button({ Id = "myButton", Name = "Click Me", Callback = function()
    btnFired = true
end })
check("Button created",              type(btn) == "table")
check("Button.Press exists",         type(btn.Press) == "function")
check("Button._focusable",           btn._focusable == true)
btn:Press()
check("Button.Press fires callback", btnFired)

local dd = sec:Dropdown({ Id = "myDrop", Name = "Mode", Options = {"A", "B", "C"}, Default = "A" })
check("Dropdown created",   type(dd) == "table")
check("Dropdown.Get = 'A'", dd:Get() == "A" or (type(dd:Get()) == "table" and dd:Get()[1] == "A"))
dd:Set("B")
check("Dropdown.Set 'B'",   dd:Get() == "B" or (type(dd:Get()) == "table" and dd:Get()[1] == "B"))

local inp = sec:Input({ Id = "myInput", Name = "Tag" })
check("Input created",    type(inp) == "table")
check("Input.Get exists", type(inp.Get) == "function")
inp:Set("hello")
check("Input.Set 'hello'", inp:Get() == "hello")

local kb = sec:Keybind({ Id = "myKeybind", Name = "Toggle Key", Default = Enum.KeyCode.F })
check("Keybind created",          type(kb) == "table")
check("Keybind.Get = F",          kb:Get() == Enum.KeyCode.F)
kb:Set(Enum.KeyCode.G)
check("Keybind.Set G",            kb:Get() == Enum.KeyCode.G)
kb:Clear()
check("Keybind.Clear = Unknown",  kb:Get() == Enum.KeyCode.Unknown)
check("Keybind._focusable",       kb._focusable == true)

local lbl = sec:Label({ Name = "Status", Text = "Ready" })
check("Label created", type(lbl) == "table")
check("Label.Get",     lbl:Get() == "Ready")
lbl:Set("Active")
check("Label.Set",     lbl:Get() == "Active")

local tog2 = sec:Toggle({ Id = "myToggle", Name = "Should reuse" })
check("Duplicate Id returns same ctrl", tog2 == tog)

tog:Set(true); sli:Set(33); inp:Set("test")
local saved = win:SaveSettings()
check("SaveSettings returns table",    type(saved) == "table")
check("SaveSettings myToggle = true",  saved["myToggle"] == true)
check("SaveSettings mySlider = 33",    saved["mySlider"] == 33)
check("SaveSettings myInput = 'test'", saved["myInput"] == "test")

tog:Set(false); sli:Set(0); inp:Set("")
win:LoadSettings(saved)
check("LoadSettings restores toggle", tog:Get() == true)
check("LoadSettings restores slider", sli:Get() == 33)
check("LoadSettings restores input",  inp:Get() == "test")

check("Toggle _focusable set",  tog._focusable == true)
check("Button _focusable set",  btn._focusable == true)
check("Keybind _focusable set", kb._focusable == true)

local tab2 = win:Tab("Advanced")
local sec2 = tab2:Section("Col A")
local sec3 = tab2:Section("Col B")
check("Tab._sections has 2 sections", #tab2._sections == 2)
check("tab2._pageWide exists",        tab2._pageWide ~= nil)
check("tab2._colLeft exists",         tab2._colLeft ~= nil)
check("tab2._colRight exists",        tab2._colRight ~= nil)

local notifOk = pcall(function()
    win:Notify({ Title = "Test", Message = "Runtime test notification", Duration = 2 })
end)
check("Notify does not error", notifOk)

check("IsDestroyed = false",     win:IsDestroyed() == false)
check("SetDisabled runs",        pcall(function() tog:SetDisabled(true) end))
check("SetVisible runs",         pcall(function() tog:SetVisible(false) end))
check("Window.ClearFocus runs",  pcall(function() win:ClearFocus() end))

local total = passed + failed
print(string.format("\n[EmberUI Test] %d/%d passed%s",
    passed, total,
    failed > 0 and string.format(" (%d FAILED)", failed) or " — all clear"
))
if failed == 0 then
    win:Notify({ Title = "Test Complete", Message = passed .. "/" .. total .. " checks passed", Duration = 5 })
end
