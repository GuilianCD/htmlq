#!/bin/env lua

local HTML = require(".html")
local CSS = require(".css")

local logger = require(".logging")




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
    logger.print("  -f, --first-only: return only the first match")
    logger.print("  -q, --quiet: Don't print warnings")
    os.exit(1)
end





local FLAGS = {
	FIRST_ONLY = {},
	NO_PRINT_ERRORS = {},
}

local LONGHAND_FLAGS = {
	["first-only"] = FLAGS.FIRST_ONLY,
	["quiet"] = FLAGS.NO_PRINT_ERRORS
}

local SHORTHAND_FLAGS = {
	["f"] = FLAGS.FIRST_ONLY,
	["q"] = FLAGS.NO_PRINT_ERRORS,
}



if #arg < 2 then
	logger.printerr("Error: Not enough arguments")
	print_usage()
	return 1
end

local flags = {}
local positionals = {}

for _, argument in ipairs(arg) do
	if argument:match("^%-%w+$") then
		for letter in argument:sub(2):gmatch("(%w)") do
			if not SHORTHAND_FLAGS[letter] then
				logger.printerr("Unknown flag: -"..letter..".")
				print_usage()
				return 1
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
			return 1
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


if not flags[ FLAGS.NO_PRINT_ERRORS ] then
	logger.enable_printing_errors()
end


if #positionals > 2 then
	logger.printerr("Error: too many arguments !")
	print_usage()
	return 1
end

local html_file = positionals[1]
local html = nil

if html_file ~= "-" then
	if not( file_exists( html_file )) then
		logger.printerr("File doesn't exist: " .. html_file)
		return 2
	end

	local handle = io.open( html_file, "r" )
	if not handle then
		logger.printerr("Failed to open file " .. html_file)
		return 2
	end

	html = handle:read("a")
else
	html = io.read()
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





if flags[FLAGS.FIRST_ONLY] then
	if #elements > 0 then
		logger.print( HTML.tostring( elements[1] ) )
	end

	return 0
end

for _, el in ipairs(elements) do
		logger.print( HTML.tostring(el) )
end
