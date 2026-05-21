local lfs = require("lfs")

for file in lfs.dir('additionals') do
    -- Skip current (.) and parent (..) directory references
    if file ~= "." and file ~= ".." then
        local path =  "additionals/" .. file
		local pathWithoutDotLua = path:match("(.*)%.lua$")
		if pathWithoutDotLua then
			require(pathWithoutDotLua:gsub("/", "."))
		end
    end
end
