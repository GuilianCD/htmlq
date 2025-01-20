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
}

local LONGHAND_FLAGS = {
	["first-only"] = FLAGS.FIRST_ONLY,
	["errors"] = FLAGS.DO_PRINT_ERRORS,
	["text"] = FLAGS.INNER_TEXT,
}

local SHORTHAND_FLAGS = {
	["1"] = FLAGS.FIRST_ONLY,
	["e"] = FLAGS.DO_PRINT_ERRORS,
	["t"] = FLAGS.INNER_TEXT,
}



if #arg < 2 then
	logger.printerr("Error: Not enough arguments")
	print_usage()
	os.exit( RETURN_CODES.ARGUMENTS_ERROR )
end

local flags = {}
local positionals = {}

for _, argument in ipairs(arg) do
	if argument:match("^%-%w+$") then
		for letter in argument:sub(2):gmatch("(%w)") do
			if not SHORTHAND_FLAGS[letter] then
				logger.printerr("Unknown flag: -"..letter..".")
				print_usage()
				os.exit( RETURN_CODES.ARGUMENTS_ERROR )
			end

			local flag = SHORTHAND_FLAGS[letter]

			if flags[flag] then
				logger.printerr("Warning: passed -" .. letter .. " flag already !")
			end

			flags[flag] = true
		end
	elseif argument:match("^%-%-[%w%-]+$") then
		local flagname = argument:sub(3)
		if not LONGHAND_FLAGS[flagname] then
			logger.printerr("Unknown flag: --"..flagname..".")
			print_usage()
			os.exit( RETURN_CODES.ARGUMENTS_ERROR )
		end

		local flag = LONGHAND_FLAGS[flagname]

		if flags[flag] then
			logger.printerr("Warning: passed --" .. flagname .. " flag already !")
		end

		flags[flag] = true
	else
		table.insert( positionals, argument )
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


if flags[FLAGS.FIRST_ONLY] then
	if #elements > 0 then
		if flags[FLAGS.INNER_TEXT] then
			logger.print( elements[1]:inner_text() )
			os.exit( RETURN_CODES.OK )
		end

		logger.print( HTML.tostring( elements[1] ) )
	end

	os.exit( RETURN_CODES.OK )
end

for _, el in ipairs(elements) do
		if flags[FLAGS.INNER_TEXT] then
			logger.print( el:inner_text() )
		else
			logger.print( HTML.tostring(el) )
		end
end
