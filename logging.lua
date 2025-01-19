
local may_print_errors = false
local errors_buffer = {}

local logger = {
	print = function( str )
		print( str or "" )
	end,
	printerr = function( str)
		str = str or ""
		if str:sub(#str,#str) ~= "\n" then
			str = str .. "\n"
		end

		if not may_print_errors then
			table.insert(errors_buffer, str)
			return
		end

		io.stderr:write(str)
	end,
	enable_printing_errors = function()
		may_print_errors = true

		for _, err in ipairs(errors_buffer) do
				io.stderr:write(err)
		end
	end,
}


return logger
