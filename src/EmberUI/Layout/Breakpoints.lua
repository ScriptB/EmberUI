--!strict

local Breakpoints = {
	Compact = 520,
	Standard = 900,
	Wide = 1440,
}

function Breakpoints.Get(width)
	if width < Breakpoints.Compact then return "Compact" end
	if width < Breakpoints.Standard then return "Standard" end
	if width < Breakpoints.Wide then return "Wide" end
	return "Expanded"
end

return Breakpoints
