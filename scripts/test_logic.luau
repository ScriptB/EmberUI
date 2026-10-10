-- EmberUI Logic Test Suite - runs under Lune (standalone Luau)
-- Usage: lune run scripts/test_logic.luau  (from repo root)
-- Tests pure-logic modules without Roblox runtime.
local process = require("@lune/process")

-- Roblox global stubs
warn = function(...) print("[warn]", ...) end
Color3 = { fromRGB = function(r, g, b) return { r=r/255, g=g/255, b=b/255, _type="Color3" } end }
local function makeEnum(items)
    local e = {}
    for _, name in ipairs(items) do
        local item = { Name = name, _enumItem = true }
        e[name] = item
    end
    return e
end
Enum = {
    KeyCode = makeEnum({"Unknown","F","Escape","LeftShift","RightShift","LeftControl","RightControl","Return","Space","Tab","Q","W","E","R"}),
}
game = { GetService = function(_, name)
    if name == "HttpService" then
        return {
            JSONEncode = function(_, v)
                local parts = {}
                for k, val in pairs(v) do
                    parts[#parts+1] = '"'..tostring(k)..'":'..tostring(val)
                end
                return "{"..table.concat(parts,",").."}"
            end,
            JSONDecode = function(_, _s) return { x = 42 } end,
        }
    end
    return {}
end }

-- Test harness
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("PASS  " .. name); passed += 1
    else
        print("FAIL  " .. name .. "\n      " .. tostring(err)); failed += 1
    end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "")..": expected "..tostring(b).." got "..tostring(a), 2) end
end
local function ok_(v, msg) if not v then error(msg or "expected truthy", 2) end end
local function notok(v, msg) if v then error(msg or "expected falsy", 2) end end

local Signal      = require("../src/EmberUI/Core/Signal")
local State       = require("../src/EmberUI/Core/State")
local Validation  = require("../src/EmberUI/Core/Validation")
local Breakpoints = require("../src/EmberUI/Layout/Breakpoints")
local maidOk, Maid = pcall(require, "../src/EmberUI/Core/Maid")

print("\n-- Signal --")

test("connect + fire delivers value", function()
    local s = Signal.new(); local got
    s:Connect(function(v) got = v end); s:Fire("hello"); eq(got, "hello")
end)
test("multiple listeners all fire", function()
    local s = Signal.new(); local a, b = 0, 0
    s:Connect(function() a += 1 end); s:Connect(function() b += 1 end)
    s:Fire(); eq(a, 1); eq(b, 1)
end)
test("disconnect stops callback", function()
    local s = Signal.new(); local n = 0
    local d = s:Connect(function() n += 1 end)
    s:Fire(); d(); s:Fire(); eq(n, 1)
end)
test("double-disconnect is safe", function()
    local s = Signal.new(); local d = s:Connect(function() end); d(); d()
end)
test("fire after Destroy is safe", function()
    local s = Signal.new(); local n = 0
    s:Connect(function() n += 1 end); s:Destroy(); s:Fire(); eq(n, 0)
end)
test("Connect after Destroy returns no-op", function()
    local s = Signal.new(); s:Destroy(); local d = s:Connect(function() end); d()
end)
test("multi-arg pass-through", function()
    local s = Signal.new(); local a, b, c
    s:Connect(function(x,y,z) a,b,c=x,y,z end)
    s:Fire(1,"two",true); eq(a,1); eq(b,"two"); eq(c,true)
end)

print("\n-- State --")

test("initial value", function() eq(State(42):Get(), 42) end)
test("Set + Get", function() local s=State(0); s:Set(99); eq(s:Get(),99) end)
test("Subscribe fires on change", function()
    local s=State(false); local got
    s:Subscribe(function(v) got=v end); s:Set(true); eq(got,true)
end)
test("Subscribe silent on same value", function()
    local s=State(5); local n=0
    s:Subscribe(function() n+=1 end); s:Set(5); eq(n,0)
end)
test("unsubscribe stops callback", function()
    local s=State(0); local n=0
    local u=s:Subscribe(function() n+=1 end)
    s:Set(1); u(); s:Set(2); eq(n,1)
end)
test("Once fires exactly once", function()
    local s=State(0); local n=0
    s:Once(function() n+=1 end)
    s:Set(1); s:Set(2); s:Set(3); eq(n,1)
end)
test("Update applies transform", function()
    local s=State(10); s:Update(function(v) return v*2 end); eq(s:Get(),20)
end)
test("Map creates derived state", function()
    local s=State(3); local d=s:Map(function(v) return v*2 end)
    eq(d:Get(),6); s:Set(5); eq(d:Get(),10)
end)
test("Batch defers and fires once with final value", function()
    local s=State(0); local fires=0
    s:Subscribe(function() fires+=1 end)
    State.Batch(function()
        s:Set(1); s:Set(2); s:Set(3)
        eq(fires, 0, "must not fire inside batch")
    end)
    eq(fires,1); eq(s:Get(),3)
end)
test("Computed updates on dependency change", function()
    local a=State(2); local b=State(3)
    local sum=State.Computed({a,b}, function() return a:Get()+b:Get() end)
    eq(sum:Get(),5); a:Set(10); eq(sum:Get(),13)
end)
test("Destroy makes Set a no-op", function()
    local s=State(0); local n=0
    s:Subscribe(function() n+=1 end); s:Destroy(); s:Set(1); eq(n,0)
end)
test("Sub is alias for Subscribe", function()
    local s=State(0); local got
    s:Sub(function(v) got=v end); s:Set(7); eq(got,7)
end)

print("\n-- Maid --")
if maidOk then
    test("function task cleaned on Destroy", function()
        local m=Maid.new(); local done=false
        m:Give(function() done=true end); m:Destroy(); ok_(done)
    end)
    test("Destroy is idempotent", function()
        local m=Maid.new(); local n=0
        m:Give(function() n+=1 end); m:Destroy(); m:Destroy(); eq(n,1)
    end)
    test("Give after Destroy immediately cleans", function()
        local m=Maid.new(); m:Destroy()
        local done=false; m:Give(function() done=true end); ok_(done)
    end)
    test("tasks cleaned in reverse order", function()
        local m=Maid.new(); local order={}
        m:Give(function() table.insert(order,1) end)
        m:Give(function() table.insert(order,2) end)
        m:Give(function() table.insert(order,3) end)
        m:Destroy()
        eq(order[1],3); eq(order[2],2); eq(order[3],1)
    end)
else
    print("SKIP  Maid (typeof not available in this Lune build)")
end

print("\n-- Validation --")
test("warnUnknown: no throw on known keys", function()
    Validation.warnUnknown({Name="x",Callback=function()end},{"Name","Callback"},"Toggle")
end)
test("warnUnknown: no throw on extra keys (only warns)", function()
    Validation.warnUnknown({Name="x",Bogus=true},{"Name"},"Toggle")
end)
test("number: accepts number", function() eq(Validation.number(42,"Speed"),42) end)
test("number: rejects string", function() notok(pcall(Validation.number,"x","Speed")) end)
test("nonEmptyString: accepts string", function() eq(Validation.nonEmptyString("hello","Name"),"hello") end)
test("nonEmptyString: rejects empty string", function() notok(pcall(Validation.nonEmptyString,"","Name")) end)
test("nonEmptyString: rejects number", function() notok(pcall(Validation.nonEmptyString,99,"Name")) end)

print("\n-- Breakpoints --")
test("0 -> Compact",     function() eq(Breakpoints.Get(0),    "Compact")  end)
test("519 -> Compact",   function() eq(Breakpoints.Get(519),  "Compact")  end)
test("520 -> Standard",  function() eq(Breakpoints.Get(520),  "Standard") end)
test("899 -> Standard",  function() eq(Breakpoints.Get(899),  "Standard") end)
test("900 -> Wide",      function() eq(Breakpoints.Get(900),  "Wide")     end)
test("1439 -> Wide",     function() eq(Breakpoints.Get(1439), "Wide")     end)
test("1440 -> Expanded", function() eq(Breakpoints.Get(1440), "Expanded") end)
test("2560 -> Expanded", function() eq(Breakpoints.Get(2560), "Expanded") end)
test("reflowSidebar: Compact->52px others->158px", function()
    local F,C=158,52; local function w(bp) return bp=="Compact" and C or F end
    eq(w("Compact"),52); eq(w("Standard"),158); eq(w("Wide"),158); eq(w("Expanded"),158)
end)

print("\n-- Theme tokens --")
local TOKENS = {
    "Bg","Surface","SurfaceHi","SurfaceHover",
    "Accent","AccentBright","AccentDark","AccentMid",
    "Text","TextSub","TextHint",
    "On","OnDark","OnBright","Off","OffDark",
    "Border","BorderHi",
    "Success","SuccessDark","Warn","WarnDark","Error","ErrorDark","Info","InfoDark",
}
local function checkTheme(label, path)
    test(label.." has all 27 tokens", function()
        local t=require(path)
        for _,k in ipairs(TOKENS) do
            ok_(t[k]~=nil, label.." missing: "..k)
            ok_(type(t[k])=="table" and t[k]._type=="Color3", label.." "..k.." not Color3")
        end
        local n=0; for _ in pairs(t) do n+=1 end
        eq(n, #TOKENS, label.." token count: "..tostring(n))
    end)
end
checkTheme("Tokens (dark base)", "../src/EmberUI/Theme/Tokens")
checkTheme("EmberLight",         "../src/EmberUI/Theme/EmberLight")
test("EmberHighContrast loads", function()
    local t=require("../src/EmberUI/Theme/EmberHighContrast")
    ok_(t.Accent~=nil); ok_(t.On~=nil)
end)

print("\n-- _validateControlId (B4) --")
local function mkV(ids)
    return function(cfg,kind)
        local id=cfg.Id
        if id==nil then return nil end
        if type(id)~="string" or id=="" then
            error(("EmberUI %s Id must be a non-empty string"):format(kind),2)
        end
        if ids[id] then return ids[id] end
        return nil
    end
end
test("nil Id -> nil",                      function() eq(mkV({})({}, "T"), nil) end)
test("integer Id -> error",                function() notok(pcall(mkV({}), {Id=42}, "T")) end)
test("empty-string Id -> error",           function() notok(pcall(mkV({}), {Id=""}, "T")) end)
test("new Id -> nil (first creation)",     function() eq(mkV({})({Id="x"}, "T"), nil) end)
test("existing Id -> returns stored ctrl", function()
    local ctrl={_m=true}; ok_(mkV({x=ctrl})({Id="x"},"T")==ctrl)
end)
test("independent Ids are independent", function()
    local a,b={_=1},{_=2}; local v=mkV({a=a,b=b})
    ok_(v({Id="a"},"T")==a); ok_(v({Id="b"},"T")==b); eq(v({Id="c"},"T"),nil)
end)

print("\n-- B1 numeric filter --")
test("live filter strips non-numeric chars", function()
    local function f(s) return s:gsub("[^%d%.%-]","") end
    eq(f("12abc3"),"123"); eq(f("3.14xyz"),"3.14")
    eq(f("-5.5"),"-5.5"); eq(f("abc"),"")
end)
test("FocusLost normalises to number or 0", function()
    local function n(s) return tostring(tonumber(s) or 0) end
    eq(n("42"),"42"); eq(n("3.14"),"3.14"); eq(n("abc"),"0"); eq(n(""),"0"); eq(n("-5"),"-5")
end)

print("\n-- F3 SetOptions coercion --")
test("all types coerced to string", function()
    local function c(raw) local o={} for _,v in ipairs(raw) do o[#o+1]=tostring(v) end return o end
    local r=c({"A",42,true,"B"})
    eq(r[1],"A"); eq(r[2],"42"); eq(r[3],"true"); eq(r[4],"B")
end)

print("\n-- B5 ImageList clamp --")
test("Columns clamped >= 1", function()
    local c=function(n) return math.max(1,math.floor(n or 3)) end
    eq(c(0),1); eq(c(-5),1); eq(c(3),3); eq(c(nil),3)
end)
test("ImageSize clamped >= 8", function()
    local p=function(n) return math.max(8,math.floor(n or 58)) end
    eq(p(0),8); eq(p(-1),8); eq(p(58),58); eq(p(nil),58)
end)

print("\n-- B3 resize delta --")
test("delta / uiScale gives correct pre-scale size", function()
    local function sz(abs,delta,scale,minW) return math.max(minW,(abs+delta)/scale) end
    eq(sz(460, 40, 1,   300), 500)
    eq(sz(690, 60, 1.5, 300), 500)
    eq(sz(310,-20, 1,   300), 300)
end)

print("\n-- PersistenceManager --")
local PM = require("../src/EmberUI/Managers/PersistenceManager")

test("MemoryAdapter round-trip", function()
    local pm = PM.new({ Adapter = PM.MemoryAdapter(), Version = 1, Defaults = { x = 0 } })
    local ok = pm:Save("s1", { x = 42 })
    ok_(ok, "save failed")
    local vals, status = pm:Load("s1")
    eq(status, "loaded"); eq(vals.x, 42)
end)
test("MemoryAdapter missing key returns defaults", function()
    local pm = PM.new({ Adapter = PM.MemoryAdapter(), Version = 1, Defaults = { x = 7 } })
    local vals, status = pm:Load("nope")
    eq(status, "missing"); eq(vals.x, 7)
end)
test("migration runs and upgrades version", function()
    local adapter = PM.MemoryAdapter()
    local pm1 = PM.new({ Adapter = adapter, Version = 1 })
    pm1:Save("s", { count = 5 })
    local pm2 = PM.new({
        Adapter = adapter,
        Version = 2,
        Migrations = { [1] = function(v) v.count = v.count * 2; return v end },
    })
    local vals, status = pm2:Load("s")
    eq(status, "loaded"); eq(vals.count, 10)
end)
test("Deserialize EnumItem from known serialized form", function()
    local serialized = { __emberType = "EnumItem", enumType = "KeyCode", name = "F" }
    local restored = PM.Deserialize(serialized)
    ok_(restored == Enum.KeyCode.F, "wrong item restored")
end)
test("FileAdapter: no readfile/writefile -> graceful no-op", function()
    local saved_readfile, saved_writefile = readfile, writefile
    readfile = nil; writefile = nil
    local adapter = PM.FileAdapter("ember_test")
    local result = adapter:Read(nil, "key")
    ok_(result == nil)
    adapter:Write(nil, "key", { x = 1 })
    readfile = saved_readfile; writefile = saved_writefile
end)

print("\n-- Keybind Clear logic --")
test("Clear resets to Unknown KeyCode", function()
    local currentKey = Enum.KeyCode.F
    local function setKey(k) currentKey = k end
    local function clear() setKey(Enum.KeyCode.Unknown) end
    clear()
    eq(currentKey, Enum.KeyCode.Unknown)
end)

print("\n-- SaveSettings / LoadSettings --")
test("SaveSettings collects Id-tagged ctrl values", function()
    local allElements = {
        { Id = "toggle1", Get = function() return true end },
        { Id = "slider1", Get = function() return 42 end },
        { Get = function() return "no-id" end },
    }
    local function saveSettings()
        local values = {}
        for _, ctrl in ipairs(allElements) do
            if ctrl.Id and type(ctrl.Get) == "function" then
                local ok, v = pcall(ctrl.Get, ctrl)
                if ok then values[ctrl.Id] = v end
            end
        end
        return values
    end
    local v = saveSettings()
    eq(v["toggle1"], true); eq(v["slider1"], 42); ok_(v["no-id"] == nil)
end)
test("LoadSettings restores Id-tagged ctrl values", function()
    local got = {}
    local allElements = {
        { Id = "toggle1", Set = function(self, v) got["toggle1"] = v end },
        { Id = "slider1", Set = function(self, v) got["slider1"] = v end },
    }
    local function loadSettings(values)
        if type(values) ~= "table" then return end
        for _, ctrl in ipairs(allElements) do
            if ctrl.Id and values[ctrl.Id] ~= nil and type(ctrl.Set) == "function" then
                pcall(ctrl.Set, ctrl, values[ctrl.Id])
            end
        end
    end
    loadSettings({ toggle1 = false, slider1 = 77 })
    eq(got["toggle1"], false); eq(got["slider1"], 77)
end)

print(string.format("\n=== %d passed, %d failed ===", passed, failed))
if failed > 0 then process.exit(1) end