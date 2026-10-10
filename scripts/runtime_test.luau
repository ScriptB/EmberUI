local process = require("@lune/process")
local fs = require("@lune/fs")

local passed, failed = 0, 0
local function check(label, cond, detail)
    if cond then
        print("[PASS] " .. label)
        passed += 1
    else
        print("[FAIL] " .. label .. (detail ~= nil and (" — " .. tostring(detail)) or ""))
        failed += 1
    end
end

local function makeSignal()
    local subs = {}
    local s = {}
    function s:Connect(fn)
        subs[#subs + 1] = fn
        return { Disconnect = function() end }
    end
    function s:Fire(...) for _, fn in ipairs(subs) do pcall(fn, ...) end end
    return s
end

local function makeInst(cls)
    local data = {
        ClassName        = cls or "Frame",
        Name             = cls or "Frame",
        Visible          = true,
        AbsoluteSize     = { X = 0, Y = 0 },
        AbsolutePosition = { X = 0, Y = 0 },
    }
    local children = {}
    local sigs = {}
    local inst
    inst = setmetatable({}, {
        __index = function(_, k)
            if data[k] ~= nil then return data[k] end
            if not sigs[k] then sigs[k] = makeSignal() end
            return sigs[k]
        end,
        __newindex = function(_, k, v)
            if k == "Parent" and type(v) == "table" then
                local pc = rawget(v, "__children")
                if pc then pc[#pc + 1] = inst end
            end
            data[k] = v
        end,
    })
    rawset(inst, "__children", children)
    function inst:GetChildren() return children end
    function inst:FindFirstChildOfClass(c)
        for _, ch in ipairs(children) do
            if ch.ClassName == c then return ch end
        end
    end
    function inst:FindFirstChild(n)
        for _, ch in ipairs(children) do
            if ch.Name == n then return ch end
        end
    end
    function inst:Destroy() end
    function inst:IsA(c) return cls == c end
    function inst:GetPropertyChangedSignal(p)
        local k = "_pcs_" .. p
        if not sigs[k] then sigs[k] = makeSignal() end
        return sigs[k]
    end
    function inst:Clone() return makeInst(cls) end
    return inst
end

local enumCache = {}
local Enum = setmetatable({}, {
    __index = function(_, eType)
        return setmetatable({}, {
            __index = function(_, name)
                local key = eType .. "_" .. name
                if not enumCache[key] then
                    enumCache[key] = setmetatable(
                        { Name = name, EnumType = eType },
                        { __tostring = function() return "Enum." .. eType .. "." .. name end }
                    )
                end
                return enumCache[key]
            end,
        })
    end,
})

local function UDim2_new(xs, xo, ys, yo)
    return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } }
end
local UDim2 = {
    new        = UDim2_new,
    fromOffset = function(x, y) return UDim2_new(0, x, 0, y) end,
    fromScale  = function(x, y) return UDim2_new(x, 0, y, 0) end,
}
local UDim    = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
local Vector2 = { new = function(x, y) x=x or 0; y=y or 0; return {X=x,Y=y,Magnitude=math.sqrt(x*x+y*y)} end }
local Color3  = {
    new    = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end,
    fromRGB = function(r, g, b) return { R=(r or 0)/255, G=(g or 0)/255, B=(b or 0)/255 } end,
}
local ColorSequence  = { new = function(...) return {} end }
local NumberSequence = { new = function(...) return {} end }
local TweenInfo      = { new = function(...) return {} end }
local CFrame         = setmetatable({ new = function(...) return {} end }, { __call = function() return {} end })
local Vector3        = setmetatable({ new = function(...) return {} end }, { __call = function() return {} end })

local mockUIS = {
    InputBegan     = makeSignal(),
    InputEnded     = makeSignal(),
    InputChanged   = makeSignal(),
    IsKeyDown      = function() return false end,
    GetKeysPressed = function() return {} end,
}

local function makeTweenService()
    return {
        Create = function(_, _inst, _info, _props)
            return { Play = function() end, Completed = makeSignal() }
        end,
    }
end

local mockCamera = setmetatable(
    { ViewportSize = Vector2.new(1920, 1080), ClassName = "Camera" },
    { __index = function(_, k) return makeInst("Camera")[k] end }
)
function mockCamera:GetPropertyChangedSignal(_p) return makeSignal() end
local mockWorkspace = { CurrentCamera = mockCamera }

local mockGame = {
    ClassName  = "DataModel",
    GetService = function(self, name)
        if name == "TweenService"     then return makeTweenService() end
        if name == "UserInputService" then return mockUIS end
        if name == "RunService"       then return { RenderStepped = makeSignal(), Heartbeat = makeSignal(), Stepped = makeSignal() } end
        if name == "Players"          then
            local pg = makeInst("PlayerGui")
            return { LocalPlayer = { PlayerGui = pg, WaitForChild = function() return pg end } }
        end
        if name == "CoreGui"          then return makeInst("CoreGui") end
        if name == "HttpService"      then
            return {
                JSONEncode = function(_, _t) return "{}" end,
                JSONDecode = function(_, _s) return {} end,
            }
        end
        return makeInst(name)
    end,
}

local env = {
    setmetatable = setmetatable,
    getmetatable = getmetatable,
    rawget       = rawget,
    rawset       = rawset,
    rawequal     = rawequal,
    rawlen       = rawlen,
    pairs        = pairs,
    ipairs       = ipairs,
    next         = next,
    select       = select,
    type         = type,
    tostring     = tostring,
    tonumber     = tonumber,
    pcall        = pcall,
    xpcall       = xpcall,
    error        = error,
    assert       = assert,
    unpack       = table.unpack,
    print        = print,
    require      = require,
    loadstring   = loadstring,
    math         = math,
    table        = table,
    string       = string,
    os           = os,
    coroutine    = coroutine,
    debug        = debug,
    Instance         = { new = makeInst },
    game             = mockGame,
    workspace        = mockWorkspace,
    Enum             = Enum,
    UDim2            = UDim2,
    UDim             = UDim,
    Vector2          = Vector2,
    Color3           = Color3,
    ColorSequence    = ColorSequence,
    NumberSequence   = NumberSequence,
    TweenInfo        = TweenInfo,
    CFrame           = CFrame,
    Vector3          = Vector3,
    UserInputService = mockUIS,
    task = {
        wait   = function() end,
        delay  = function() end,
        spawn  = function(f) pcall(f) end,
        defer  = function(f) pcall(f) end,
        cancel = function() end,
    },
    typeof = function(v)
        if type(v) ~= "table" then return type(v) end
        if v.R ~= nil and v.G ~= nil and v.B ~= nil then return "Color3" end
        if v.EnumType ~= nil then return "EnumItem" end
        return "table"
    end,
    tick  = os.clock,
    time  = os.clock,
    warn  = function(...) print("[warn]", ...) end,
    wait  = function() end,
    spawn = function(f) pcall(f) end,
}
env._G = env

local bundleRaw = fs.readFile("../EmberUI.lua")
local bundleSrc = bundleRaw:sub(1,3) == "\xEF\xBB\xBF" and bundleRaw:sub(4) or bundleRaw
local fn, loadErr = loadstring(bundleSrc, "@EmberUI")
check("EmberUI.lua loads (no syntax error)", fn ~= nil, loadErr)
if not fn then process.exit(1) end
setfenv(fn, env)

local runOk, EmberUI = pcall(fn)
check("EmberUI module executes (no runtime error)", runOk, not runOk and EmberUI or nil)
if not runOk then process.exit(1) end

check("EmberUI is a table",      type(EmberUI) == "table")
check("EmberUI.Window callable", type(EmberUI.Window) == "function")
check("EmberUI.State callable",  pcall(function() return EmberUI.State(0) end))

local winOk, win = pcall(function() return EmberUI:Window({ Title = "MockTest", Width = 700, Height = 520 }) end)
check("Window() no error",    winOk, not winOk and win or nil)
if not winOk then process.exit(1) end
check("win.Tab callable",     type(win.Tab) == "function")
check("win.Notify callable",  type(win.Notify) == "function")
check("GetBreakpoint string", type(win:GetBreakpoint()) == "string")
check("GetScale number",      type(win:GetScale()) == "number")
check("IsDestroyed=false",    win:IsDestroyed() == false)

local tab; local tabOk = pcall(function() tab = win:Tab("Controls") end)
check("Tab() no error",       tabOk, not tabOk and tab or nil)
check("tab.Section callable", tabOk and type(tab.Section) == "function")

local sec; local secOk = pcall(function() sec = tab:Section("General") end)
check("Section() no error", secOk, not secOk and sec or nil)

local tog; local togOk = pcall(function()
    tog = sec:Toggle({ Id = "tog1", Name = "Toggle", Default = false, Callback = function() end })
end)
check("Toggle() no error",         togOk, not togOk and tog or nil)
check("Toggle.Get()=false",        togOk and tog:Get() == false)
tog:Set(true);  check("Toggle.Set(true)",  togOk and tog:Get() == true)
tog:Set(false); check("Toggle.Set(false)", togOk and tog:Get() == false)
check("Toggle._focusable",         togOk and tog._focusable == true)
check("Toggle._activate callable", togOk and type(tog._activate) == "function")

local sli; local sliOk = pcall(function()
    sli = sec:Slider({ Id = "sli1", Name = "Slider", Min = 0, Max = 100, Default = 50 })
end)
check("Slider() no error", sliOk, not sliOk and sli or nil)
check("Slider.Get()=50",   sliOk and sli:Get() == 50)
sli:Set(75);  check("Slider.Set(75)",   sliOk and sli:Get() == 75)
sli:Set(999); check("Slider clamped",   sliOk and sli:Get() == 100)

local btn; local btnFired = false
local btnOk = pcall(function()
    btn = sec:Button({ Id = "btn1", Name = "Btn", Callback = function() btnFired = true end })
end)
check("Button() no error",     btnOk, not btnOk and btn or nil)
check("Button._focusable",     btnOk and btn._focusable == true)
pcall(function() btn:Press() end)
check("Button.Press fires cb", btnFired)

local dd; local ddOk = pcall(function()
    dd = sec:Dropdown({ Id = "dd1", Name = "Drop", Options = { "A", "B", "C" }, Default = "A" })
end)
check("Dropdown() no error", ddOk, not ddOk and dd or nil)
local function ddGet() return type(dd:Get()) == "table" and dd:Get()[1] or dd:Get() end
check("Dropdown.Get()='A'",  ddOk and ddGet() == "A")
dd:Set("B"); check("Dropdown.Set('B')", ddOk and ddGet() == "B")

local inp; local inpOk = pcall(function()
    inp = sec:Input({ Id = "inp1", Name = "Input" })
end)
check("Input() no error", inpOk, not inpOk and inp or nil)
inp:Set("hello"); check("Input.Set/Get", inpOk and inp:Get() == "hello")

local kb; local kbOk = pcall(function()
    kb = sec:Keybind({ Id = "kb1", Name = "Key", Default = Enum.KeyCode.F })
end)
check("Keybind() no error",        kbOk, not kbOk and kb or nil)
check("Keybind.Get()=F",           kbOk and kb:Get() == Enum.KeyCode.F)
kb:Set(Enum.KeyCode.G); check("Keybind.Set(G)",    kbOk and kb:Get() == Enum.KeyCode.G)
kb:Clear();             check("Keybind.Clear()=Unknown", kbOk and kb:Get() == Enum.KeyCode.Unknown)
check("Keybind._focusable",        kbOk and kb._focusable == true)
check("Keybind._activate callable",kbOk and type(kb._activate) == "function")

local lbl; local lblOk = pcall(function()
    lbl = sec:Label({ Name = "Lbl", Text = "Ready" })
end)
check("Label() no error",    lblOk, not lblOk and lbl or nil)
check("Label.Get()='Ready'", lblOk and lbl:Get() == "Ready")
lbl:Set("Active"); check("Label.Set/Get", lblOk and lbl:Get() == "Active")

local dup; local dupOk = pcall(function() dup = sec:Toggle({ Id = "tog1", Name = "Dup" }) end)
check("Dup Id returns same ctrl", dupOk and dup == tog)

tog:Set(true); sli:Set(33); inp:Set("abc")
local saved = win:SaveSettings()
check("SaveSettings table",      type(saved) == "table")
check("SaveSettings tog1=true",  saved["tog1"] == true)
check("SaveSettings sli1=33",    saved["sli1"] == 33)
check("SaveSettings inp1='abc'", saved["inp1"] == "abc")
tog:Set(false); sli:Set(0); inp:Set("")
win:LoadSettings(saved)
check("LoadSettings toggle", tog:Get() == true)
check("LoadSettings slider", sli:Get() == 33)
check("LoadSettings input",  inp:Get() == "abc")

local tab2; local tab2Ok = pcall(function() tab2 = win:Tab("Advanced") end)
check("Tab2() no error", tab2Ok, not tab2Ok and tab2 or nil)
if tab2Ok then
    pcall(function() tab2:Section("A") end)
    pcall(function() tab2:Section("B") end)
    check("tab2._sections=2",  #tab2._sections == 2)
    check("tab2._pageWide",    tab2._pageWide ~= nil)
    check("tab2._colLeft",     tab2._colLeft ~= nil)
    check("tab2._colRight",    tab2._colRight ~= nil)
end

local notifOk = pcall(function() win:Notify({ Title = "T", Message = "M", Duration = 1 }) end)
check("Notify() no error", notifOk)
check("ClearFocus no error", pcall(function() win:ClearFocus() end))

local total = passed + failed
print(string.format("\n[runtime_test] %d/%d passed%s",
    passed, total,
    failed > 0 and string.format(" (%d FAILED)", failed) or " — all clear"
))
if failed > 0 then process.exit(1) end
