-- Turns big numbers into short text: 1500 -> "1.50K", 2300000 -> "2.30M".
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.cash(amount: number): string
	amount = math.floor(amount)
	if amount < 1000 then
		return tostring(amount)
	end

	local index = 1
	-- 999.5 or more would round up to "1000" with this suffix (999,999,575 -> "1000M"), so it
	-- moves up to the next one ("1.00B") instead.
	while amount >= 999.5 and index < #SUFFIXES do
		amount /= 1000
		index += 1
	end

	local pattern = if amount >= 100 then "%.0f%s" elseif amount >= 10 then "%.1f%s" else "%.2f%s"
	return string.format(pattern, amount, SUFFIXES[index])
end

return Format
