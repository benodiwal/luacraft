--- Luacraft module
-- @classmod Luacraft
local Luacraft = {}
Luacraft.__index = Luacraft

local Command = require "luacraft.command"
local chalk = require "chalk"
local ftable = require("f.table")
local fstring = require("f.string")
local Pcall = require"luacraft.pcall"
local Parsed = require "luacraft.parsed"
local ThemeColor = require"luacraft.themecolor"
local lfs = require "lfs"
--- Create a Luacraft instance
-- @tparam table setup Options
-- @string[opt=""] setup.title Title message for your CLI.
-- @tparam[opt=""] string setup.tag CLI Command to execute your program.
-- @tparam[opt=""] string setup.description CLI description.
-- @tparam[opt="0.0.1"] string setup.version CLI version.
-- @tparam[opt=false] boolean setup.prevent_help Prevent help message if not command found.
-- @treturn Luacraft
function Luacraft.new(setup)
    setup = setup or {}
    local config = {
        title = setup.title or "",
        tag = setup.tag or "",
        description = setup.description or "",
        version = setup.version or "0.1.0",
        author = setup.author or "",
        root_path = setup.root_path or "",
        prevent_help = setup.prevent_help or false,
        default_action = nil,
        devmode = setup.devmode or false,
        commands = {} -- Store commands
    }
    local luacraft = setmetatable(config, Luacraft)
    luacraft:apply_theme(config.theme)
    -- Adding default commands
    -- Help command
    local default_action = luacraft:command("help [cmd]","Help command"):action(function(parsed, command, lum)
        if(parsed.cmd)then
            local command = luacraft:find_cmd(parsed.cmd)
            if(command)then command:usage_extended(luacraft.tag) else luacraft:help(true) end
        else
            luacraft:help(true)
        end
    end)

    luacraft:action(default_action, {})
    -- Version
    luacraft:command("--version","Version",{alias = {"-v"}}):action(function(parsed, command, lum)
        lum.theme.cli.text(luacraft.tag .. ": " .. luacraft.version)
    end)

    return luacraft
end

--- Set a default action to execute if any command if found
-- @tparam function command Default action
-- @tparam table params Default params passed to Default action function
-- @treturn Luacraft
function Luacraft:action(command, params)
    if(type(command) == "string") then command = self:find_cmd(command) end
    params = params or {}
    assert(getmetatable(command) == Command, "default command is not an instance of Command")
    if(command:check_parsed(params)) then
        self.default_action = function()
            command:run(params, command, self)
        end
        self.default_action_command = command
    end
    return self
end

--- Apply a theme
-- @tparam table|nil theme Theme to apply. See README.md file
-- @treturn Luacraft
function Luacraft:apply_theme(theme)
    local base = {
        cli = {
            title =  "",
            text = "",
            category = ""
        },
        command = {
            definition = "",
            description = "",
            argument = "",
            option = "",
            category = ""
        },
        primary = "",
        secondary = "",
        success = "",
        warning = "",
        error = ""
    }

    theme = theme or require"luacraft.themes.default"

    if(type(theme) == "string")then
        self.pcall(function()
            theme = require("luacraft.themes." .. theme)
        end):fail(function(err)
            theme = require"luacraft.themes.default"
        end)
    end

    local default_color = chalk.white
    function create_theme(base, theme, fn)
        ftable.for_each(base, function(value, index, t)
            if(type(value) == "string")then
                base[index] = fn(theme[index], index, t)
            elseif(type(value) == "table")then
                base[index] = create_theme(base[index], theme[index], fn)
            end
        end)
        return base
    end
    function create_color(color)
        local colorize = chalk[color] or default_color
        return ThemeColor(colorize, color)
    end
    --- Theme table
    -- @table theme
    -- @tfield table cli
    -- @tfield ThemeColor cli.title
    -- @tfield ThemeColor cli.text
    -- @tfield ThemeColor cli.category
    -- @tfield table command
    -- @tfield ThemeColor command.definition 
    -- @tfield ThemeColor command.description
    -- @tfield ThemeColor command.argument
    -- @tfield ThemeColor command.option
    -- @tfield ThemeColor command.category
    -- @tfield ThemeColor primary
    -- @tfield ThemeColor secondary
    -- @tfield ThemeColor success
    -- @tfield ThemeColor warning
    -- @tfield ThemeColor error
    self.theme = create_theme(base, theme, function(value, index, t)
        return create_color(value)
    end)
    return self
end

--- Create a new command
-- @tparam string command Parse that string to extract arguments names and their requirement.
-- @tparam[opt=""] ?string|table description Command description or table as config.
-- @tparam[opt={}] table config Options.
-- @tparam[opt] string config.schema Command schema.
-- @tparam[opt=""] string config.description Command description.
-- @tparam[opt={}] table config.positional_args Command description.
-- @tparam[opt] {options} config.options CommandOptions
-- @tparam[opt=false] boolean config.hide Hide from help command
-- @tparam[opt=false] boolean config.main Set as main cli command
-- @tparam[opt] function config.action Command action function.
-- @treturn Command
-- @usage
-- luacraft:command("mycmd <req1> [opt1] [...opt_array]", "My command description") -- you can chaining methods to define the command
--
-- -- or create a command with full definition
-- luacraft:command("mycmd <req1> [opt1] [...opt_array]", "My command description", {
--      positional_args = {
--          req1 = "Description for required argument",
--          opt1 = {description = "Description for optional argument", default = "my_default_value"},
--          opt_array = {description = "Description for optional arguments lieke array", default = {"1","2"}}
--      },
--      hide = false
--      main = false
--      action = function(parsed, command, luacraft)
--          --do something here
--      end
-- })
--
-- -- or
-- luacraft:command("mycmd <req1> [opt1] [...opt_array]", {
--      description = "My command description",
--      positional_args = {
--          req1 = "Description for required argument",
--          opt1 = {description = "Description for optional argument", default = "my_default_value"},
--          opt_array = {description = "Description for optional arguments lieke array", default = {"1","2"}}
--      },
--      hide = false
--      main = false
--      action = function(parsed, command, luacraft)
--          --do something here
--      end
-- })
--
-- -- or pass all like a table
-- luacraft:command({
--      shema = "mycmd <req1> [opt1] [...opt_array]",    
--      description = "My command description"  ,  
--      positional_args = {
--          req1 = "Description for required argument",
--          opt1 = {description = "Description for optional argument", default = "my_default_value"},
--          opt_array = {description = "Description for optional arguments lieke array", default = {"1","2"}}
--      },
--      hide = false
--      main = false
--      action = function(parsed, command, luacraft)
--          --do something here
--      end
-- })
function Luacraft:command(command, description, config)
    if(type(description) == "table")then
        config = description
    end
    config = config or {}
    if(type(description) == "string")then config.description = description end
    local cmd = Command.new(command, config, self) -- Create command with config and store it in a table
    local cmd_setted = self:find_cmd(cmd:names())
    if(cmd_setted)then self:error("\"" .. cmd.name .. "\" command has name/alias what was setted before in \"".. cmd_setted.name.."\"") end
    if(config.main)then
        self:action(cmd, {})
    end
    table.insert(self.commands, cmd)
    table.sort(self.commands, function(a,b) return a.name < b.name end)
    return cmd
end

--- Load command of a directory
-- @tparam string folderpath Relative path to load commands (.lua files). Use as require format.
-- @treturn Luacraft
-- @usage
-- --"commands_folder" is a folder in same directory that main lua file.
-- luacraft:commands_dir("commands_folder")
-- -- or
-- luacraft:commands_dir("commands_folder.subfolder")
function Luacraft:commands_dir(folderpath)
    -- local cwd = lfs.currentdir() .. "\\" .. folderpath
    local separator = package.config:sub(1,1) -- / or \\ to know OS
    local base_directory = self.root_path .. separator .. folderpath
    for filename,i in lfs.dir(base_directory) do
        if(fstring.ends_with(filename, ".lua"))then
            local file = folderpath .. "." .. filename:sub(1,-5)
            self.pcall(function()
                local data = require(file)
                data.file = file:gsub("%.","/")
                self:command(data.command, data.description, data)
            end):fail(function(err)
                self:error("Command adding from file: " .. file:gsub("%.","/") .. "\n".. err)
            end)
        end
    end
    return self
end

--- Execute command on shell
-- @tparam string command Shell command to execute
-- @tparam ?function fn Callback to execute when the shell command finished
-- @treturn ?string
function Luacraft:execute(command, fn)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    if(fn) then fn(result) end
    return result
end

--- Search a command by name
-- @tparam string cmd_name Command name to search.
-- @treturn Command|nil
function Luacraft:find_cmd(cmd_name)
    if(type(cmd_name) == 'string') then cmd_name = {cmd_name} end
    return ftable.find(self.commands,function(command)
        local ret
        ftable.for_each(cmd_name, function(cmd_iname)
            if(command.name == cmd_iname or ftable.includes(command.alias, cmd_iname))then ret = true end
        end)
        return ret
    end)
end

--- Print Help message
-- @tparam[opt=false] bool ignore_flag ignore_flag Ignore Luacraft prevent_help to show hep message.
-- If prevent_help option is placed in Luacraft init, it ignores print Luacraft:help() when it is called
function Luacraft:help(ignore_flag)
    if self.prevent_help and not ignore_flag then return end
    print(self.theme.cli.title.color(self.title .. " (v" .. self.version .. ")".. ((#self.author > 0 and " by " .. self.author) or "") .. "\n") ..self.theme.cli.category.color("Usage: ")
    .. self.tag .. " <command> [options] ")
    if(#self.description > 0)then print(self.theme.cli.category.color("Description: ") .. self.description) end
    if(self.default_action and self.default_action_command) then print(self.theme.cli.category.color("Default command: ")..self.default_action_command.name.. ((#self.default_action_command.description > 0 and " => " ..self.default_action_command.description) or "")) end
    self.theme.cli.category("Commands:")
    ftable.for_each(self.commands, function(cmd)
        cmd:usage()
    end)
    print()
    print(self.theme.cli.category.color("Use: ") .. self.theme.command.definition.color(self.tag .. " help <command>") .. " to get more info about that command")
end

--- Parse message
-- @tparam table|string message Message splited by spaces and "". Execute Command if it is found.
-- @treturn Parsed
function Luacraft:parse(message)
    -- if(type(message) == "table") then message = table.join(message,"-") end
    local args
    if(type(message) == "string")then
        args = {}
        local i = 1
        for s in message:gsub(
            '"([^"]+)"',
            function(x)
                return x:gsub("%s+", "\0")
            end
        ):gmatch "%S+" do
            local v = s:gsub("%z+", " ")
                table.insert(args, v)
            -- if (i > 2) then
            --     local v = s:gsub("%z+", " ")
            --     table.insert(args, v)
            -- end
            -- i = i + 1
            -- print( s:gsub("%z+", " ") )
        end
    else
        args = message
    end

    -- Create a table what contains parsed arguments. Add this to Luacraft.parsed
    -- @table Parsed
    local parsed = Parsed(args)

    if (not args[1]) then 
        self:run()
    else
        local cmd = self:find_cmd(args[1]) -- Search a command
        if not cmd then self:run() else -- If not a command found, then execute Luacraft:help()
            self:dev(function()
                parsed:setarg("_cmd", cmd.name)
                -- parsed._cmd = cmd.name
            end)
            local indexarg = 2
            if (#cmd.arguments > 0) then -- Parse required and optional arguments
                for _, cmd_arg in ipairs(cmd.arguments) do
                    parsed[cmd_arg.name] = cmd_arg.default or (cmd_arg.type == "optlist" and ftable()) or nil
                    if (args[indexarg] and not fstring.starts_with(args[indexarg],"-")) then
                        if(cmd_arg.type == "optlist")then
                            parsed[cmd_arg.name], indexarg = optlist_parser(args, indexarg)
                        else
                            -- parsed[cmd_arg.name] = args[indexarg]
                            parsed:setarg(cmd_arg.name, args[indexarg])
                            indexarg = indexarg + 1
                        end
                    else
                        if(cmd_arg.type == "req")then -- if required argument is missing, then execute Command:usage() to show help usage
                            return cmd:usage(true,self.tag or "")
                        end
                    end
                end
            end
            for ka = indexarg, #args do -- Parse flags arguments
                local a = args[ka]
                local opt = cmd:has_option(a)
                if opt then
                    if (opt.type == "flag") then
                        parsed:setarg(opt.name, true)
                    elseif (args[ka + 1] and not fstring.starts_with(args[ka + 1], "-")) then
                        parsed:setarg(opt.name, opt.transform(args[ka + 1]))
                        ka = ka + 2
                    else
                        parsed:setarg(opt.name, true)
                    end
                end
            end

            -- Add default opt to parsed table if that opt is nil (not defined)
            ftable.for_each(cmd.options, function(opt, index, array)
                if(not (opt.default == nil) and parsed[opt.name] == nil) then
                    parsed:setarg(opt.name, opt.default)
                end
            end)

            self:dev(function() parsed:print() end)
            
            -- Execute command
            self.pcall(function() cmd:run(parsed, cmd, self) end):fail(function(err) self:error(err) end)
        end
    end
    return parsed
end

function Luacraft:run()
    if(self.default_action) then
        self.default_action()
    else
        self:help()
    end
end

return Luacraft
