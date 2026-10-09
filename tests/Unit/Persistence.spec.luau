local PersistenceManager = require("../../src/EmberUI/Managers/PersistenceManager")

local adapter = PersistenceManager.MemoryAdapter()
local manager = PersistenceManager.new({
	Adapter = adapter,
	Version = 2,
	Defaults = { enabled = false, speed = 16 },
	Migrations = {
		[1] = function(values)
			values.speed = values.walkSpeed or 16
			values.walkSpeed = nil
			return values
		end,
	},
})

local missing, missingStatus = manager:Load("settings")
assert(missingStatus == "missing" and missing.enabled == false)

adapter:Write("settings", { version = 1, values = { enabled = true, walkSpeed = 24 } })
local migrated, status = manager:Load("settings")
assert(status == "loaded" and migrated.enabled == true and migrated.speed == 24)

assert(manager:Save("settings", { enabled = false, speed = 32 }))
local saved, savedStatus = manager:Load("settings")
assert(savedStatus == "loaded" and saved.enabled == false and saved.speed == 32)
