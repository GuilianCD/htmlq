local logger = require("logging")

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

local function shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end


local M = {}

local RAW_TEXT_TAGS = {
	script = true,
	style = true,
	pre = true
}

-- void tags are content-less, or so-called "self-closing", tags
local VOID_TAGS = {
	area = true,
	base = true,
	br = true,
	col = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	link = true,
	meta = true,
	param = true, -- deprecated
	source = true,
	track = true,
	wbr = true,
}

local INLINE_TAGS = {
	-- Text formatting
	a = true,
	abbr = true,
	b = true,
	bdi = true,
	bdo = true,
	cite = true,
	code = true,
	data = true,
	dfn = true,
	em = true,
	i = true,
	kbd = true,
	mark = true,
	q = true,
	ruby = true,
	s = true,
	samp = true,
	small = true,
	span = true,
	strong = true,
	sub = true,
	sup = true,
	time = true,
	u = true,
	var = true,

	-- Interactive elements
	button = true,
	label = true,
	select = true,
	textarea = true,

	-- Media/content
	img = true,
	picture = true,
	map = true,
	object = true,

	-- Line break
	br = true,
	wbr = true,

	-- Forms
	input = true,
	output = true,
	progress = true,
	meter = true,

	-- Scripting
	script = true,
	noscript = true,
	template = true,
}


function M.make_dom_element( tag_name, parent_elem )
	local o = {
		tag_name = tag_name,
		attributes = {},
		content = "",

		children = {},
		parent = parent_elem,

		get_child_index = function( self )
			if not self.parent then
				return -1
			end

			for i, child in ipairs(self.parent.children) do
				if child == self then return i end
			end
		end,

		get_next_sibling = function( self )
			if not self.parent then return nil end

			local found_self = false
			for _, child in ipairs(self.parent.children) do
				if found_self then
					return child
				end

				if child == self then
					found_self = true
				end
			end

			return nil
		end,

		check_simple_selector = function( self, selector )
			return M.check_simple_selector( self, selector )
		end,

		foreach = function( self, fn )
			fn( self )

			for _, child in ipairs(self.children or {}) do
				child:foreach( fn )
			end
		end,

		inner_text = function(self)
			if self.tag_name == ":text" then
				return self.content
			end

			local text = ""
			for _, child in ipairs(self.children) do
				text = text .. child:inner_text()

				if not INLINE_TAGS[child.tag_name] then
					text = text .. "\n"
				end
			end

			return text
		end
	}

	if parent_elem then
		table.insert( parent_elem.children, o )
	end

	local mt = {
		__newindex = function(table, key, value)
			-- Allow modification of existing attributes
			if rawget(table.attributes, key) ~= nil then
				rawset(table.attributes, key, value)
			else
				-- Prevent adding new attributes
				error("Cannot add new attribute to DOM element: " .. tostring(key))
			end
		end,
		__index = function(table, key)
			-- Allow access to attributes
			return rawget(table.attributes, key)
		end
	}

	setmetatable(o, mt)
	return o
end



function M.preprocess( content )
	-- remove "self closing" slashes as they MUST be ignored (spec)
	-- and would cause problems
	content = content:gsub("/%s*>", ">")
	-- remove whitespace at the start of "</closing>" tags.
	content = content:gsub("</%s*/%s*", "</")

	return content
end


function M.tokenise( content )
	local TOKENS = {}

	-- state
	local in_tag = false
	local currently_opened_quotes = nil
	local text_memory = ""

	local skipping_from = nil
	local skip_target = nil
	local skip_mode = "before"

	local function set_skipping_to( str, mode )
		mode = mode or "before"
		if mode ~= "before" and mode ~= "after" then
			error("Unexpected skipping mode: " .. mode .. ", in looking for " .. str)
		end

		skip_target = str
		skip_mode = mode
	end



	local i = 1

	while i <= #content do
		local char = content:sub(i,i)

		if skip_target ~= nil then
			if skipping_from == nil then
				skipping_from = i
			end

			if skip_mode == "before" then
				local end_i =  i + #skip_target - 1

				if trim(content:sub(i, end_i)) == skip_target then
					table.insert( TOKENS, {type="TEXT", value=content:sub(skipping_from, i-1)} )

					-- release from skip
					--i = end_i - 1
					i = i - 1
					skip_target = nil
					skipping_from = nil
				end

				goto continue
			else
				local start_i =  i - #skip_target + 1

				if trim(content:sub(start_i, i)) == skip_target then
					table.insert( TOKENS, {type="TEXT", value=content:sub(skipping_from, start_i-1)} )

					-- release from skip
					i = start_i
					skip_target = nil
					skipping_from = nil
				end

				goto continue
			end



		end




		if char == "<" then
			if content:sub(i, i+3) == "<!--" then
				set_skipping_to("-->", "after")
				goto continue
			end

			if content:sub(i, i+1) == "<!" then
				i = content:find(">", i)
				goto continue
			end

			---------------------------------
			if #text_memory ~= 0 then
				table.insert( TOKENS, {type="TEXT", value=text_memory} )
				text_memory = ""
			end

			in_tag = true

			-- closing tag
			if content:sub(i, i+1) == "</" then
				table.insert( TOKENS, {type="START_CLOSING_TAG"} )
				i = i+1
				goto continue
			end

			table.insert( TOKENS, {type="START_OPENING_TAG"} )
			goto continue
		end

		if char == ">" then
			if #text_memory ~= 0 then
				if in_tag and currently_opened_quotes == nil then
					local word = trim(text_memory)

					if TOKENS[#TOKENS] and ( TOKENS[#TOKENS].type == "START_OPENING_TAG") then
						if RAW_TEXT_TAGS[word] then
							logger.printerr("Warning: "..word.." tags may contain text that would be incorrectly parsed as HTML.")
							-- made possible because of the whitespace removal at the start
							set_skipping_to("</" .. word)
						end
					end

					if not word:match("^%s*$") then
						table.insert( TOKENS, {type="WORD", value=word})
					end
				else
					table.insert( TOKENS, {type="TEXT", value=text_memory} )
				end

				text_memory = ""
			end

			in_tag = false
			table.insert( TOKENS, {type = "END_TAG"} )

			goto continue
		end



		if in_tag then
			if currently_opened_quotes == nil and char:match("%s") then
				if #text_memory ~= 0 then
					local word = trim(text_memory)

					if TOKENS[#TOKENS] and ( TOKENS[#TOKENS].type == "START_OPENING_TAG" ) then
						if RAW_TEXT_TAGS[word] then
							logger.printerr("Warning: "..word.." tags may contain text that would be incorrectly parsed as HTML.")
							-- made possible because of the whitespace removal at the start
							set_skipping_to("</" .. word)
							text_memory = ""

							-- advance to closing ">"
							i = content:find(">", i)
						end
					end

					if not word:match("^%s*$") then
						table.insert( TOKENS, {type="WORD", value=word})
						text_memory = ""
					end

					goto continue
				end
			end

			if char == "'" or char == '"' then
				-- found matching closing quote type
				if char == currently_opened_quotes then
					currently_opened_quotes = nil
				elseif currently_opened_quotes == nil then
					currently_opened_quotes = char
				end
			end

			text_memory = text_memory .. char
			goto continue
		else
			text_memory = text_memory .. char
			goto continue
		end


		::continue::
		i = i+1
	end


	return TOKENS
end


function M.check_simple_selector(element, selector)
	-- Skip text nodes
	if element.tag_name == ":text" then
		return false
	end

	-- Check tag name if specified
	if selector.tag_name and element.tag_name ~= selector.tag_name then
		return false
	end

	-- Check ID if specified
	if selector.id and element.attributes.id ~= selector.id then
		return false
	end

	-- Check classes if specified
	if selector.class and #selector.class > 0 then
		local element_classes = element.attributes.class
		if not element_classes then
			return false
		end

		for _, class in ipairs(selector.class) do
			local found = false
			for _, elem_class in ipairs(element_classes) do
				if elem_class == class then
					found = true
					break
				end
			end
			if not found then
				return false
			end
		end
	end

	for attr_name, attr_value in pairs(selector.attributes_values) do
		local elem_attr_value = element.attributes[attr_name]
		if elem_attr_value ~= attr_value then
			return false
		end
	end

	-- Check attribute presence selectors
	for _, attr_name in ipairs(selector.attributes_present) do
		if not element.attributes[attr_name] then
			return false
		end
	end

	return true
end

function M.query_simple_selector(document, selector)
	local matches = {}

	local function traverse(node)
		if M.check_simple_selector(node, selector) then
			table.insert(matches, node)
		end

		for _, child in ipairs(node.children) do
			traverse(child)
		end
	end

	traverse(document)
	return matches
end


function M.parse_tokens_into_document( TOKENS )
	local DOCUMENT = M.make_dom_element(nil, nil)
	local current_doc_element = DOCUMENT
	local in_opening_tag_for = nil

	local i = 1
	while i <= #TOKENS do
		local token = TOKENS[i]

		if token.type == "WORD" then
			if current_doc_element.tag_name == ":text" then
				current_doc_element = current_doc_element.parent
			end


			if i > 0 and TOKENS[i-1].type == "START_OPENING_TAG" then
				local new_elem = M.make_dom_element( token.value, current_doc_element )
				current_doc_element = new_elem
				in_opening_tag_for = token.value

				goto continue
			end

			if i > 0 and TOKENS[i-1].type == "START_CLOSING_TAG" then
				local curr_elem = current_doc_element

				while curr_elem.parent and curr_elem.tag_name ~= token.value do
					curr_elem = curr_elem.parent
				end

				if curr_elem.parent == nil then
					-- reached DOCUMENT root
					logger.printerr("Warning: reached document root while trying to match for closing " .. token.value .. " token.")
					current_doc_element = DOCUMENT
				else
					current_doc_element = curr_elem.parent
				end


				goto continue
			end



			if in_opening_tag_for then
				local pattern = "([%w-]+)=['\"](.+)['\"]"

				local name, raw_value = token.value:match(pattern)

				if name == nil or raw_value == nil then
					name = token.value:match("([%w-]+)")

					if name == nil then
						error("Unrecognised word: " .. tostring(name) .. " (Token ".. tostring(i) .." , type=" .. tostring(token.type) .. ", value=" .. tostring(token.value) .. ")")
					end

					current_doc_element.attributes[name] = true

					goto continue
				end


				local value = nil
				if raw_value == "" or raw_value == nil then
					value = nil
				else
					value = trim(raw_value)

					if name == "class" then
						local classes = {}

						for class in value:gmatch("%S+") do
							table.insert( classes, class )
						end

						value = classes
					end
				end

				current_doc_element.attributes[name] = value

				goto continue
			end

		end


		if token.type == "END_TAG" then
			if in_opening_tag_for then
				if VOID_TAGS[in_opening_tag_for] then
					if current_doc_element.parent == nil then
						-- reached DOCUMENT root
						current_doc_element = DOCUMENT
					else
						current_doc_element = current_doc_element.parent
					end
				end

			end

			in_opening_tag_for = nil

			goto continue
		end


		if token.type == "TEXT" then
			local new_elem = M.make_dom_element( ":text", current_doc_element )
			new_elem.content = token.value
			current_doc_element = new_elem

			goto continue
		end


		::continue::
		i = i+1
	end

	M.clean_text_nodes( DOCUMENT )

	return DOCUMENT
end


function M.clean_text_nodes(node)
	if node.tag_name ~= ":text" then
		-- Don't clean anything in raw text tags
		if RAW_TEXT_TAGS[node.tag_name] then
			return
		end

		for _, child in ipairs( shallow_copy(node.children) ) do
			M.clean_text_nodes( child )
		end
		return
	end

	-- purge content-less text nodes
	if #trim(node.content) == 0 then
		if not node.parent then
			error("Text node without a parent; should be impossible !")
		end

		for i, child in ipairs( shallow_copy(node.parent.children) ) do
			if child == node then
				table.remove( node.parent.children, i )
				break
			end
		end

		return
	end

	node.content = node.content:gsub("%s+", " ")
end


function M._tostring(node, indent, include_internal_pseudoelements)
	-- Default indentation is 0 (root level)
	indent = indent or 0
	include_internal_pseudoelements = include_internal_pseudoelements or false

	local is_pseudo_element = (node.tag_name or ":root"):sub(1,1) == ":"


	local indent_level_str = "  "
	-- Create the indentation string (e.g., "  " for each level)
	local indent_str = string.rep(indent_level_str, indent)

	if node.tag_name == ":text" then
		local str = ""

		if include_internal_pseudoelements then
			str = str .. "<:text>"
		end

		str = str .. node.content

		if include_internal_pseudoelements then
			str = str .. "</:text>"
		end

		return str
	end

	local node_name = ""

	if not is_pseudo_element or include_internal_pseudoelements then
		-- Print the current node's tag name
		node_name = node_name .. "\n" .. indent_str .. "<" .. (node.tag_name or ":root")
	end

	-- Print attributes if any
	if next(node.attributes) ~= nil then
		for attr, value in pairs(node.attributes) do
			if type(value) == "table" then
				node_name = node_name .. " " .. attr .. "=\""
				for i, val in ipairs( value ) do
					if i > 1 then node_name = node_name .. " " end
					node_name = node_name .. tostring(val)
				end
				node_name = node_name .. "\""
			else
				node_name = node_name .. " " .. attr .. "=\"" .. tostring(value) .. "\""
			end
		end
	end

	if not is_pseudo_element or include_internal_pseudoelements then
		node_name = node_name .. ">"
	end

	local next_indent = indent + 1
	if is_pseudo_element and not include_internal_pseudoelements then
		next_indent = indent
	end

	-- Recursively print children
	for _, child in ipairs(node.children) do
		node_name = node_name .. M._tostring(child, next_indent, include_internal_pseudoelements)
	end

	if not VOID_TAGS[node.tag_name] and ( not is_pseudo_element or include_internal_pseudoelements ) then
		-- Print the closing tag
		local end_indent = ""
		local closing_text_tag = "</:text>"
		if node_name:sub(#node_name, #node_name) == ">" and node_name:sub(#node_name - #closing_text_tag + 1, #node_name) ~= closing_text_tag then
			end_indent = "\n" .. indent_str
		end
		node_name = node_name .. end_indent .. "</" .. (node.tag_name or ":root") .. ">"
	end

	return node_name
end

function M.tostring(node, base_indent, include_internal_pseudoelements)
	return trim( M._tostring(node, base_indent, include_internal_pseudoelements) )
end




function M.parse( html_string )
	local clean_html = M.preprocess( html_string )

	local tokens = M.tokenise( clean_html )

	local document = M.parse_tokens_into_document( tokens )

	return document
end

return M
