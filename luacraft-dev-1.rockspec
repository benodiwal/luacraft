package = "luacraft"
version = "dev-1"
source = {
   url = "git://github.com/benodiwal/luacraft",
   branch = "main"
}
description = {
   summary = "A command paser library in lua",
   homepage = "https://github.com/benodiwal/luacraft",
}
dependencies = {
   "lua >= 5.1, < 5.5",
   "chalk>=0.1.0",
   "luafilesystem>=1.8.0",
   "f>=0.1.0",
}
build = {
    type = "builtin",
    modules = {
      ["luacraft.command"] = "luacraft/command.lua",
      ["luacraft.init"] = "luacraft/init.lua",
      ["luacraft.luacraft"] = "luacraft/luacraft.lua",
      ["luacraft.parsed"] = "luacraft/parsed.lua",
      ["luacraft.pcall"] = "luacraft/pcall.lua",
      ["luacraft.themecolor"] = "luacraft/themecolor.lua",
      ["luacraft.themes.acid"] = "luacraft/themes/acid.lua",
      ["luacraft.themes.default"] = "luacraft/themes/default.lua"
   }, 
}
