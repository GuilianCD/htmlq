#!/bin/env lua
--
--     Copyright (C) 2025 Guilian Celin--Davanture
--
--     This program is free software: you can redistribute it and/or
--     modify it under the terms of the GNU General Public License as
--     published by the Free Software Foundation, version 3.
--
--     This program is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--     See the GNU General Public License for more details.
--
--     You should have received a copy of the GNU General Public License
--     along with this program.
--     If not, see https://www.gnu.org/licenses/.
--



local HTML = require("html")
local CSS = require("css")

local logger = require("logging")




local function file_exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end



local function print_usage()
	logger.print("Usage: lua main.lua [FLAGS] <html_path_or_minus> <css_selector>")
	logger.print("  html_path_or_minus: Path to HTML file or '-' for stdin")
	logger.print("  css_selector: CSS selector to search for")
	logger.print()
	logger.print("  Flags:")
	logger.print("  -1, --first-only: return only the first match")
	logger.print("  -e, --errors: print warnings")
	logger.print("  -t, --text: Print only the innerText of the matched elements")
	logger.print("  -a, --select-attribute: Print the value of the attribute on matched elements. Supersedes -t.")
end



local RETURN_CODES = {
	OK = 0,
	NOTHING_FOUND = 1,
	ARGUMENTS_ERROR = 2,
	FAILED_INPUT = 3,
}



local FLAGS = {
	FIRST_ONLY = {},
	DO_PRINT_ERRORS = {},
	INNER_TEXT = {},
	SELECT_ATTRIBUTE = {}
}

local LONGHAND_FLAGS = {
	["first-only"] = FLAGS.FIRST_ONLY,
	["errors"] = FLAGS.DO_PRINT_ERRORS,
	["text"] = FLAGS.INNER_TEXT,
	["select-attribute"] = FLAGS.SELECT_ATTRIBUTE,
}

local SHORTHAND_FLAGS = {
	["1"] = FLAGS.FIRST_ONLY,
	["e"] = FLAGS.DO_PRINT_ERRORS,
	["t"] = FLAGS.INNER_TEXT,
	["a"] = FLAGS.SELECT_ATTRIBUTE,
}


local FLAG_NEEDS_VALUE = {
	[FLAGS.SELECT_ATTRIBUTE] = true,
}



if #arg < 2 then
	logger.printerr("Error: Not enough arguments")
	print_usage()
	os.exit( RETURN_CODES.ARGUMENTS_ERROR )
end

local flags = {}
local positionals = {}

local i = 1
while i <= #arg do
	local argument = arg[i]

	-- Handle shorthand flags (-a, -1, etc.)
	if argument:match("^%-%w+$") then
		local flag_str = argument:sub(2)

		-- Handle single-letter flags
		if #flag_str == 1 then
			local letter = flag_str
			local flag = SHORTHAND_FLAGS[letter]

			if not flag then
				logger.printerr("Unknown flag: -"..letter)
				print_usage()
				os.exit(RETURN_CODES.ARGUMENTS_ERROR)
			end

			-- Handle flags that require values
			if FLAG_NEEDS_VALUE[flag] then
				if i == #arg then
					logger.printerr("Flag -"..letter.." requires a value")
					os.exit(RETURN_CODES.ARGUMENTS_ERROR)
				end
				flags[flag] = arg[i+1]
				i = i + 2  -- Skip next argument as it's the value
			else
				-- Handle regular boolean flags
				if flags[flag] then
					logger.printerr("Warning: passed -"..letter.." flag already!")
				end
				flags[flag] = true
				i = i + 1
			end

		else
			-- Handle grouped flags (-abc)
			for letter in flag_str:gmatch("(%w)") do
				local flag = SHORTHAND_FLAGS[letter]

				if not flag then
					logger.printerr("Unknown flag in group: -"..letter)
					print_usage()
					os.exit(RETURN_CODES.ARGUMENTS_ERROR)
				end

				if FLAG_NEEDS_VALUE[flag] then
					logger.printerr("Cannot use value-taking flags in groups: -"..letter)
					os.exit(RETURN_CODES.ARGUMENTS_ERROR)
				end

				if flags[flag] then
					logger.printerr("Warning: passed -"..letter.." flag already!")
				end
				flags[flag] = true
			end
			i = i + 1
		end

		-- Handle long flags (--flag)
	elseif argument:match("^%-%-") then
		local flagname = argument:sub(3)
		local flag = LONGHAND_FLAGS[flagname]

		if not flag then
			logger.printerr("Unknown flag: --"..flagname)
			print_usage()
			os.exit(RETURN_CODES.ARGUMENTS_ERROR)
		end

		-- Handle flags that require values
		if FLAG_NEEDS_VALUE[flag] then
			if i == #arg then
				logger.printerr("Flag --"..flagname.." requires a value")
				os.exit(RETURN_CODES.ARGUMENTS_ERROR)
			end
			flags[flag] = arg[i+1]
			i = i + 2  -- Skip next argument as it's the value
		else
			-- Handle regular boolean flags
			if flags[flag] then
				logger.printerr("Warning: passed --"..flagname.." flag already!")
			end
			flags[flag] = true
			i = i + 1
		end

	else
		-- Handle positional arguments
		table.insert(positionals, argument)
		i = i + 1
	end
end



if flags[ FLAGS.DO_PRINT_ERRORS ] then
	logger.enable_printing_errors()
end


if #positionals > 2 then
	logger.printerr("Error: too many arguments !")
	print_usage()
	os.exit( RETURN_CODES.ARGUMENTS_ERROR )
end

local html_file = positionals[1]
local html = nil

if html_file ~= "-" then
	if not( file_exists( html_file )) then
		logger.printerr("File doesn't exist: " .. html_file)
		os.exit( RETURN_CODES.FAILED_INPUT )
	end

	local handle = io.open( html_file, "r" )
	if not handle then
		logger.printerr("Failed to open file " .. html_file)
		os.exit( RETURN_CODES.FAILED_INPUT )
	end

	html = handle:read("a")
else
	html = io.read("a")
end

local document = HTML.parse( html )
local css_selector = CSS.parse( positionals[2] )


local current_selector = css_selector


local elements = {}
-- start with all elements matching the first selector
document:foreach(function( el )
	if el:check_simple_selector( current_selector.selector ) then
		table.insert( elements, el )
	end
end)

while current_selector.combinator ~= nil do
	local next_selector = current_selector.next

	local new_elements = {}

	if current_selector.combinator == CSS.COMBINATORS.DESCENDANT then
		for _, element in ipairs( elements ) do
			element:foreach(function( el )
				if el:check_simple_selector( next_selector.selector ) then
					table.insert( new_elements, el )
				end
			end)
		end

		goto continue
	end

	if current_selector.combinator == CSS.COMBINATORS.DIRECT_DESCENDANT then
		for _, element in ipairs( elements ) do
			for _, child in ipairs( element.children ) do
				if child:check_simple_selector( next_selector.selector ) then
					table.insert( new_elements, child )
				end
			end
		end

		goto continue
	end

	if current_selector.combinator == CSS.COMBINATORS.NEXT_SIBLING then
		for _, element in ipairs( elements ) do
			local next_sibling = element:get_next_sibling()
			while next_sibling and next_sibling.tag_name == ":text" do
				next_sibling = next_sibling:get_next_sibling()
			end

			if next_sibling and next_sibling:check_simple_selector( next_selector.selector ) then
				table.insert( new_elements, next_sibling )
			end
		end

		goto continue
	end

	if current_selector.combinator == CSS.COMBINATORS.SUBSEQUENT_SIBLING then
		for _, element in ipairs( elements ) do
			local sibling = element:get_next_sibling()
			while sibling ~= nil do
				if sibling:check_simple_selector( next_selector.selector ) then
					table.insert( new_elements, sibling )
				end

				sibling = sibling:get_next_sibling()
			end
		end

		goto continue
	end

	::continue::
	elements = new_elements
	current_selector = next_selector
end



if #elements == 0 then
	os.exit( RETURN_CODES.NOTHING_FOUND )
end

local MAX_NUMBER_OF_ELEMENTS_TO_SHOW = #elements
if flags[FLAGS.FIRST_ONLY] then
	MAX_NUMBER_OF_ELEMENTS_TO_SHOW = 1
end





local attr = flags[FLAGS.SELECT_ATTRIBUTE]
if attr then
	local spoof_nil = {}
	local attrs = {}

	local i = 1
	while i <= MAX_NUMBER_OF_ELEMENTS_TO_SHOW do
		local el = elements[i]

		local attribute_value = el.attributes[attr]

		table.insert( attrs, attribute_value or spoof_nil )

		i = i+1
	end

	local nb_non_nil_values = 0
	for _, val in ipairs(attrs) do
		if val ~= spoof_nil then
			nb_non_nil_values = nb_non_nil_values + 1
		end
	end

	if nb_non_nil_values == 0 then
		os.exit( RETURN_CODES.NOTHING_FOUND )
	end

	for _, val in ipairs(attrs) do
		if val ~= spoof_nil then
			print(val)
		else
			print()
		end
	end

	os.exit( RETURN_CODES.OK )
end

end
