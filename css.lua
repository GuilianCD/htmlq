local M = {}

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end


local COMBINATORS = {
	DESCENDANT = {},
	DIRECT_DESCENDANT = {},
	NEXT_SIBLING = {},
	SUBSEQUENT_SIBLING = {},
}
M.COMBINATORS = COMBINATORS

local COMBINATOR_CHARS = {
	[">"] = COMBINATORS.DIRECT_DESCENDANT,
	["+"] = COMBINATORS.NEXT_SIBLING,
	["~"] = COMBINATORS.SUBSEQUENT_SIBLING
}






local function create_tokeniser(input)
	local pos = 1
	local len = #input

	local function peek()
		if pos > len then return nil end
		return input:sub(pos, pos)
	end

	local function next()
		local char = peek()
		if char then pos = pos + 1 end
		return char
	end

	local function read_identifier()
		local result = ""
		while pos <= len do
			local char = peek()
			if char and char:match("[%w-]") then
				result = result .. next()
			else
				break
			end
		end
		return result
	end

	return {
		peek = peek,
		next = next,
		read_identifier = read_identifier,
		pos = function() return pos end
	}
end


local function parse_compound_selector( tokeniser )
	local selector = {
		tag_name = nil,
		id = nil,
		class = {},
		attributes_values = {},
		attributes_present = {},
	}

	--local selectors = {}

	-- Parse first part (type or universal)
	local char = tokeniser.peek()
	if char == "*" then
		tokeniser.next()
		--table.insert(selectors, {type = "universal"})
		selector.tag_name = "*"
	elseif char and char:match("[%w-]") then
		local name = tokeniser.read_identifier()
		if name ~= "" then
			--table.insert(selectors, {type = "type", value = name})
			selector.tag_name = name
		end
	end

	-- Parse additional class or ID selectors
	while true do
		char = tokeniser.peek()
		if not char then break end

		if char == "." then
			tokeniser.next() -- consume '.'
			local name = tokeniser.read_identifier()
			if name == "" then
				error("Expected class name at position " .. tokeniser.pos())
			end
			--table.insert(selectors, {type = "class", value = name})
			table.insert( selector.class, name )
		elseif char == "#" then
			tokeniser.next() -- consume '#'
			local name = tokeniser.read_identifier()
			if name == "" then
				error("Expected id at position " .. tokeniser.pos())
			end
			--table.insert(selectors, {type = "id", value = name})
			selector.id = name
		elseif char == "[" then
			tokeniser.next() -- consume leading [

			local name = tokeniser.read_identifier()

			if tokeniser.peek() == "=" then
				tokeniser.next()

				if tokeniser.peek() ~= "\"" then
					error("Expected opening quote \" at pos " .. tokeniser.pos() )
				end
				tokeniser.next() -- consume leading "

				local value = ""
				while tokeniser.peek() ~= "\"" do
					value = value .. tokeniser.peek()
					tokeniser.next()
				end

				tokeniser.next() -- consume trailing "

				selector.attributes_values[name] = value
			else
				table.insert( selector.attributes_present, name )
			end

			if tokeniser.peek() ~= "]" then
				error("Expected closing bracket (']') at " .. tokeniser.pos())
			end

			tokeniser.next() -- consume trailing ]
		else
			break
		end
	end

	return selector
end


local function parse_combinator( tokeniser )
	-- Skip leading whitespace
	while tokeniser.peek() and tokeniser.peek():match("%s") do
		tokeniser.next()
	end

	local char = tokeniser.peek()
	if not char then return nil end

	if char == ">" or char == "+" or char == "~" then
		tokeniser.next()
		-- Skip trailing whitespace
		while tokeniser.peek() and tokeniser.peek():match("%s") do
			tokeniser.next()
		end
		return COMBINATOR_CHARS[char]
	else
		-- Make sure next character isn't an explicit combinator
		char = tokeniser.peek()
		if char and not (char == ">" or char == "+" or char == "~") then
			return COMBINATORS.DESCENDANT
		end
	end

	return nil
end




function M.parse( input )
	input = trim( input )

	local tokeniser = create_tokeniser( input )

	local output = { selector = parse_compound_selector( tokeniser ) }
	local current = output

	-- Parse combinations of combinators and compound selectors
	while true do
		local combinator = parse_combinator( tokeniser )
		if not combinator then
			current.combinator = nil
			current.next = nil
			break
		end

		local next_selector = parse_compound_selector( tokeniser )
		current.combinator = combinator
		current.next = { selector = next_selector }
		current = current.next
	end

	return output
end


return M

