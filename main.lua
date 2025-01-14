#!/bin/env lua

local html = require(".html")


local file = io.open("test.html", "r")

if file == nil then
	error("File doesn't exist")
end

local content = file:read("a")

html.print_document( html.parse( content ) )
