function recursiveRequire(folder)
   for _, file in ipairs(love.filesystem.getDirectoryItems(folder)) do
      local path = folder..'/'..file
      if love.filesystem.isDirectory(path) then
         recursiveRequire(path)
      else
         local pathWithoutDotLua = path:match('(.*)%.lua$')
         if pathWithoutDotLua then
            require(pathWithoutDotLua:gsub('/', '.'))
         end
      end
   end
end

recursiveRequire 'additionnals'
