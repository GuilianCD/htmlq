#!/bin/env lua

local html = require(".html")
local css = require(".css")


local file = io.open("small.html", "r")

if file == nil then
	error("File doesn't exist")
end

local content = file:read("a")

local doc = html.parse( content )


print("Write a css selector:")
local whole_selector = css.parse( io.read() )
local current_selector = whole_selector


local elements = {}
-- start with all elements matching the first selector
doc:foreach(function( el )
	if el:check_simple_selector( current_selector.selector ) then
		table.insert( elements, el )
	end
end)

while current_selector.combinator ~= nil do
	local next_selector = current_selector.next

	local new_elements = {}

	if current_selector.combinator == css.COMBINATORS.DESCENDANT then
		for _, element in ipairs( elements ) do
			element:foreach(function( el )
				if el:check_simple_selector( next_selector.selector ) then
					table.insert( new_elements, el )
				end
			end)
		end

		goto continue
	end

	if current_selector.combinator == css.COMBINATORS.DIRECT_DESCENDANT then
		for _, element in ipairs( elements ) do
			for _, child in ipairs( element.children ) do
				if child:check_simple_selector( next_selector.selector ) then
					table.insert( new_elements, child )
				end
			end
		end

		goto continue
	end

	if current_selector.combinator == css.COMBINATORS.NEXT_SIBLING then
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

	if current_selector.combinator == css.COMBINATORS.SUBSEQUENT_SIBLING then
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






for _, el in ipairs(elements) do
	print( html.tostring( el ) )
end



