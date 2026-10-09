--!strict

local Logger = {}

function Logger.callbackError(context: string, err: any)
	warn(("[EmberUI] %s callback failed: %s"):format(context, tostring(err)))
end

function Logger.deprecated(message: string)
	warn("[EmberUI] Deprecated: " .. message)
end

return Logger
