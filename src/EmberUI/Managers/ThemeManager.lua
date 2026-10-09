--!strict

local ThemeManager = {}
ThemeManager.__index = ThemeManager
local colorProperties = { "BackgroundColor3", "TextColor3", "ImageColor3", "ScrollBarImageColor3", "Color" }

function ThemeManager.new(tokens, themes)
	return setmetatable({ _tokens = tokens, _base = table.clone(tokens), _themes = themes, _roots = {}, _active = "Ember Dark" }, ThemeManager)
end
function ThemeManager:Register(root) table.insert(self._roots, root) end
function ThemeManager:Unregister(root)
	for index, current in ipairs(self._roots) do if current == root then table.remove(self._roots, index); break end end
end
function ThemeManager:GetName() return self._active end
function ThemeManager:SetTheme(name)
	local overrides = self._themes[name]
	if not overrides then error(("EmberUI unknown theme '%s'"):format(tostring(name)), 2) end
	local replacements = {}
	for key, previous in pairs(self._tokens) do
		local nextValue = overrides[key] or self._base[key]
		if typeof(previous) == "Color3" and nextValue ~= previous then replacements[previous] = nextValue end
	end
	for _, root in ipairs(self._roots) do
		if root.Parent then
			for _, instance in ipairs(root:GetDescendants()) do
				for _, property in ipairs(colorProperties) do
					local ok, current = pcall(function() return instance[property] end)
					if ok and replacements[current] then pcall(function() instance[property] = replacements[current] end) end
				end
			end
		end
	end
	for key in pairs(self._tokens) do self._tokens[key] = overrides[key] or self._base[key] end
	self._active = name
end
return ThemeManager
