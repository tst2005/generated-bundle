#!/usr/bin/env lua
do --{{
local sources, priorities = {}, {};assert(not sources["obey.strings"],"module already exists")sources["obey.strings"]=([===[-- <pack obey.strings> --
local strings = {}

strings.description = 'A simple and configurable task automation tool.'

strings.semver = {0,1,0}
strings.version = 'v'..table.concat(strings.semver, '.')
strings.long_version = 'OBEY - '..strings.version

strings.copyright = 'COPYRIGHT (c) 2017 Pablo A. Mayobre (Positive07)'
strings.repository = 'https://github.com/Positive07/obey'
strings.documentation = 'https://positive07.github.com/obey'

strings.license = [[MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]

strings.usage = function (app)
  return strings.long_version..[[

]]..strings.description..[[


Usage:
]]..app..[[ (-h | --help)
> Display this usage message

]]..app..[[ (-v | --version)
> Prints the currently installed version of OBEY

]]..app..[[ (-l | --list)
> Shows a list of available commands in the current directory.

]]..app..[[ [command] [arguments]
> If the current directory has a command.lua and the file returns a table with
  commands, you can use OBEY to run any such command.

Example 'command.lua':
return {
  example = function ()
    print('Hello World!')
  end
}

--]]..app..[[ example
--Prints: Hello World!

Links:
OBEY on Github: ]]..strings.repository..[[

Documentation: ]]..strings.documentation
end

return strings
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.loader"],"module already exists")sources["obey.loader"]=([===[-- <pack obey.loader> --
local protected_call = (require 'obey.execute').call

local noop = function () end

local function isFunction (value)
  if type(value) == 'function' then
    return true
  elseif type(value) == 'table' then
    local mt = getmetatable(value)
    if type(mt) == 'table' and isFunction(mt.__call) then
      return true
    end
  end
end

local require, next, type = require, next, type

local function wrap_command (env, fn)
  return function (...)
    local ok, result = protected_call(env, fn, ...)

    if ok then
      return isFunction(result) and result() or result
    else -- Error
      print(result)
      return 1
    end
  end
end

local loader = function (output, parsed)
  local dirsep = package.config:sub(1, 1)

  local path = ('.%s?.lua;.%s?%sinit.lua;'):format(dirsep, dirsep, dirsep)
  package.path = (path .. package.path):gsub(';;', ';')

  local file = '.'..dirsep..'commands.lua'

  if not os.rename(file, file) then -- Check if file exists
    return nil, 'Couldn\'t find commands.lua file in the current directory'
  end

  -- In the future we could sandbox the environment
  local env = _G or _ENV -- luacheck: compat

  env.obey = require 'obey'
  env.obey.parsed = parsed

  local load = function ()
    return require 'commands'
  end

  if not output then
    env.print = noop
    env.io.write = noop
  end

  local ok, orders = protected_call(env, load)

  local typ = type(orders)

  if not ok then
    return nil, orders
  elseif typ ~= 'table' then
    return nil, 'Expected commands.lua to return a table, but got a/an '..typ..' instead'
  else
    local protected_orders = {}

    for k, v in next, orders, nil do
      if type(k) == 'string' and type(v) == 'function' then
        protected_orders[k] = wrap_command(env, v)
      end
    end

    return protected_orders
  end
end

return loader
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.start"],"module already exists")sources["obey.start"]=([===[-- <pack obey.start> --
local main = require "obey.main"
local args = rawget(_G, 'arg') or {}

return os.exit(main(args))
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.interface"],"module already exists")sources["obey.interface"]=([===[-- <pack obey.interface> --
local loader = require 'obey.loader'

local strings = require 'obey.strings'
local usage, long_version = strings.usage, strings.long_version

local print, pairs, ipairs = print, pairs, ipairs

local types = {}

function types.help (parsed)
  print(usage(parsed.app))
  return 0
end

function types.version ()
  print(long_version)
  return 0
end

function types.list (parsed)
  local list, err = loader(false, parsed)

  if not list then
    print(err)
    return 1
  end

  local cmds = {}

  for k, _ in pairs(list) do
    cmds[#cmds + 1] = k
  end

  table.sort(cmds)

  print('Available commands:')
  for _, cmd in ipairs(cmds) do
    print('  $> '..parsed.app..' '..cmd)
  end

  return 0
end

function types.run (parsed)
  local list, err = loader(true, parsed)

  if not list then
    print(err)
    return 1
  end

  if list[parsed.order] then
    return list[parsed.order](parsed)
  else
    print('No such order found in "commands.lua"')
    return 1
  end
end

local function interface (parsed, args)
  return types[parsed.type](parsed, args)
end

return interface
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.arguments"],"module already exists")sources["obey.arguments"]=([===[-- <pack obey.arguments> --
local next, concat = next, table.concat
local gsub, sub, match = string.gsub, string.sub, string.match

local split = function (str)
  local result = {}

  for i=1, #str do
    result[#result + 1] = sub(str, i, i)
  end

  return result
end

local parse = function (str)
  if not str then return end

  local value = {}
  local extra
  local first = sub(str, 1, 1)
  str = sub(str, 2)

  while true do
    local start, follow, finish = match(str, '([^\\'..first..']*)(.)(.*)')
    value[#value + 1] = start

    if follow == '\\' then
      value[#value + 1] = sub(finish, 1, 1)
      str = sub(finish, 2)
    else
      value = concat(value, '')
      extra = finish
      break
    end
  end

  return value, extra
end

local get_obey = function (arguments)
  local start = 1

  for k, _ in next, arguments do
    if k < start then start = k end
  end

  local obey = {}

  for i=start, 0 do
    local index = i - start + 1
    obey[index] = arguments[i]
  end

  return obey
end

local get_app = function (obey)
  local command = obey[#obey]

  return gsub(match(command or '', '[^/\\]+$'), '%.[^%.]+$', '')
end

local get_type = function (command)
  if command == '--help' or command == '-h' or command == nil then
    return 'help'
  elseif command == '--list' or command == '-l' then
    return 'list'
  elseif command == '--version' or command == '-v' then
    return 'version'
  else
    return 'run'
  end
end

local get_args = function (arguments)
  local args = {}

  for i=1, #arguments do
    args[i - 1] = arguments[i]
  end

  return args
end

local get_flags = function (args)
  local flags = {}

  for i=0, #args do
    local arg = args[i]

    if not arg then
      break
    end

    local flag = {}

    if sub(arg, 1, 2) == '--' then
      flag.type = 'Named Argument'
      flag.name = sub(match(arg, '--[^="\']+'), 3)

      local value = match(arg, '^--'..flag.name..'=?(.+)')

      flag.value, flag.extra = parse(value)
    elseif sub(arg, 1, 1) == '-' then
      flag.type = 'Short Flag'
      flag.complete_flag = sub(match(arg, '-[^="\']+'), 2)
      flag.order = split(flag.complete_flag)

      flag.flags = {}
      for j=1, #flag.order do
        local name = flag.order[j]
        flag.flags[name] = (flag.flags[name] or 0) + 1
      end

      local value = match(arg, '^-'..flag.complete_flag..'=?(.+)')

      flag.value, flag.extra = parse(value)
    else
      flag.type = 'Argument'
      flag.value = parse(arg)
    end

    flags[i] = flag
  end

  return flags
end

local cli = function (arguments)
  local parsed = {
    raw = arguments
  }

  parsed.obey = get_obey(arguments)

  parsed.app = get_app(parsed.obey)

  parsed.type = get_type(arguments[1])

  parsed.order = arguments[1]

  parsed.args = get_args(arguments)

  parsed.flags = get_flags(parsed.args)

  return parsed, arguments
end

return cli
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey"],"module already exists")sources["obey"]=([===[-- <pack obey> --
local obey = {}

local unpack = unpack or table.unpack -- luacheck: compat

obey.execute = require 'obey.execute'
obey.plugins = require 'obey.plugins'

local str = require 'obey.strings'

obey.__VERSION = str.long_version
obey.__SHORT_VERSION = str.version
obey.__DESCRIPTION = str.description
obey.__SEMVER = {unpack(str.semver)}
obey.__LICENSE = str.copyright..'\n\n'..str.license
obey.__URL = str.repository

return obey
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.main"],"module already exists")sources["obey.main"]=([===[-- <pack obey.main> --
local arguments = require 'obey.arguments'
local interface = require 'obey.interface'

local main = function (args)
  return interface(arguments(args))
end

return main
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.execute"],"module already exists")sources["obey.execute"]=([===[-- <pack obey.execute> --
local unpack = unpack or table.unpack -- luacheck: compat
local xpcall, traceback = xpcall, debug.traceback
local gsub, tostring = string.gsub, tostring

local execute = {}

-- luacheck: push compat
-- All rights of setfenv and getfenv go to Leafo
-- http://leafo.net/guides/setfenv-in-lua52-and-above.html
local setfenv = setfenv or function (fn, env)
  local i = 1

  while true do
    local name = debug.getupvalue(fn, i)
    if name == "_ENV" then
      debug.upvaluejoin(fn, i, (function()
        return env
      end), 1)
      break
    elseif not name then
      break
    end

    i = i + 1
  end

  return fn
end

local getfenv = getfenv or function (fn)
  local i = 1
  while true do
    local name, val = debug.getupvalue(fn, i)
    if name == "_ENV" then
      return val
    elseif not name then
      break
    end
    i = i + 1
  end
end
-- luacheck: pop

execute.setfenv = setfenv
execute.getfenv = getfenv

local function error_handler (msg)
  return traceback("Error: " .. gsub(tostring(msg), 2, "\n[^\n]+$", ""))
end

local function protect (func)
  return function (...)
    local args = {...}

    local f = function ()
      return func(unpack(args))
    end

    return xpcall(f, error_handler)
  end
end

execute.protect = protect

function execute.call(env, fn, ...)
  fn = setfenv(fn, env)

  fn = protect(fn)

  return fn(...)
end

return execute
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["obey.plugins"],"module already exists")sources["obey.plugins"]=([===[-- <pack obey.plugins> --
local msg = 'The requested plugin is not installed in the system,'..
            'use LuaRocks to install an Obey compatible package'

local loaded = {}

local Plugins = {
  loaded = loaded
}

Plugins.load = function (name)
  if type(name) ~= 'string' then
    error('bad argument #1 to obey.plugin (string expected, got '..type(name)..')', 2)
  elseif #name == 0 then
    error('bad argument #1 to obey.plugin (you must specify a plugin name)', 2)
  end

  if loaded[name] then
    return true, loaded[name]
  end

  local ok, result = pcall(require, name .. '.obey')

  if ok then
    loaded[name] = result
    return true, result
  else
    return false, msg
  end
end

return Plugins
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
	add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end; --}};
do -- preload auto aliasing...
	local p = require("package").preload
	for k,v in pairs(p) do
		if k:find("%.init$") then
			local short = k:gsub("%.init$", "")
			if not p[short] then
				p[short] = v
			end
		end
	end
end
require "obey.start"
