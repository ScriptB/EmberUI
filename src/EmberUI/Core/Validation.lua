--!strict

local Validation = {}

function Validation.warnUnknown(config: { [string]: any }, supported: { string }, context: string)
	local allowed: { [string]: boolean } = {}
	for _, key in ipairs(supported) do allowed[key] = true end
	for key in pairs(config) do
		if not allowed[key] then
			warn(("[EmberUI] %s does not support configuration key '%s'"):format(context, key))
		end
	end
end

function Validation.number(value: any, name: string, level: number?): number
	if type(value) ~= "number" then error(("EmberUI %s must be a number"):format(name), (level or 1) + 1) end
	return value
end

function Validation.nonEmptyString(value: any, name: string, level: number?): string
	if type(value) ~= "string" or value == "" then
		error(("EmberUI %s must be a non-empty string"):format(name), (level or 1) + 1)
	end
	return value
end

return Validation
