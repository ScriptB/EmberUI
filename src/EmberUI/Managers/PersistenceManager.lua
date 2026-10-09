--!strict

local PersistenceManager = {}
PersistenceManager.__index = PersistenceManager

local function clone(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, item in pairs(value) do copy[clone(key)] = clone(item) end
	return copy
end

function PersistenceManager.Serialize(value)
	local kind = typeof(value)
	if kind == "Color3" then return { __emberType = "Color3", r = value.R, g = value.G, b = value.B } end
	if kind == "EnumItem" then return { __emberType = "EnumItem", enumType = tostring(value.EnumType), name = value.Name } end
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[PersistenceManager.Serialize(key)] = PersistenceManager.Serialize(item) end
	return result
end

function PersistenceManager.Deserialize(value)
	if type(value) ~= "table" then return value end
	if value.__emberType == "Color3" then return Color3.new(value.r, value.g, value.b) end
	if value.__emberType == "EnumItem" then
		local enumType = tostring(value.enumType):gsub("Enum%.", "")
		return Enum[enumType][value.name]
	end
	local result = {}
	for key, item in pairs(value) do result[PersistenceManager.Deserialize(key)] = PersistenceManager.Deserialize(item) end
	return result
end

function PersistenceManager.MemoryAdapter()
	local storage = {}
	return {
		Read = function(_, key) return clone(storage[key]) end,
		Write = function(_, key, value) storage[key] = clone(value) end,
	}
end

function PersistenceManager.new(options)
	options = options or {}
	if not options.Adapter then error("EmberUI PersistenceManager requires an Adapter", 2) end
	if type(options.Adapter.Read) ~= "function" or type(options.Adapter.Write) ~= "function" then
		error("EmberUI persistence Adapter needs Read and Write functions", 2)
	end
	return setmetatable({
		_adapter = options.Adapter,
		_version = options.Version or 1,
		_migrations = options.Migrations or {},
		_defaults = clone(options.Defaults or {}),
	}, PersistenceManager)
end

function PersistenceManager:Load(key)
	local ok, stored = pcall(function() return self._adapter:Read(key) end)
	if not ok then return clone(self._defaults), "read_failed" end
	if stored == nil then return clone(self._defaults), "missing" end
	if type(stored) ~= "table" or type(stored.version) ~= "number" or type(stored.values) ~= "table" then
		return clone(self._defaults), "corrupt"
	end
	local version, values = stored.version, PersistenceManager.Deserialize(stored.values)
	while version < self._version do
		local migrate = self._migrations[version]
		if type(migrate) ~= "function" then return clone(self._defaults), "migration_missing" end
		local migrated, result = pcall(migrate, values)
		if not migrated or type(result) ~= "table" then return clone(self._defaults), "migration_failed" end
		values, version = result, version + 1
	end
	if version > self._version then return clone(self._defaults), "newer_schema" end
	local merged = clone(self._defaults)
	for field, value in pairs(values) do merged[field] = value end
	return merged, "loaded"
end

function PersistenceManager:Save(key, values)
	if type(key) ~= "string" or key == "" then error("EmberUI persistence key must be a non-empty string", 2) end
	if type(values) ~= "table" then error("EmberUI persistence values must be a table", 2) end
	local payload = { version = self._version, values = PersistenceManager.Serialize(values) }
	local ok, err = pcall(function() self._adapter:Write(key, payload) end)
	if not ok then return false, err end
	return true
end

return PersistenceManager
