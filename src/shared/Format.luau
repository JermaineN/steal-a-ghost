-- Turns big numbers into short text: 1500 -> "1.50K", 2300000 -> "2.30M".
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.cash(amount: number): string
	amount = math.floor(amount)
	if amount < 1000 then
		return tostring(amount)
	end

	local index = 1
	while amount >= 1000 and index < #SUFFIXES do
		amount /= 1000
		index += 1
	end

	local pattern = if amount >= 100 then "%.0f%s" elseif amount >= 10 then "%.1f%s" else "%.2f%s"
	return string.format(pattern, amount, SUFFIXES[index])
end

return Format
