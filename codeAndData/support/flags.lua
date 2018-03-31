--[[

Examples of usage

REQUIRING

local Flags = require 'stuf.flags.flags'

GLOBAL

Good when defing flags across multiple lua files.
In these files, do:

Flags.global {
  ['boolean_flag'] = true,
  ['string_flag'] = 'hey',
  ['numerical_flag'] = 3.14,
}

In the main file, do:

local flags = Flags.global:processArgs(arg)
or
local flags = Flags.global{...}:processArgs(arg)

NOTICE

    When using global flags, the 'require' function for all files must
    come on top in the main file and in the all other files.
    The Flags.global.add must be the first command as well.

LOCAL

flags = Flags {
  ['boolean_flag'] = true,
  ['string_flag'] = 'hey',
  ['numerical_flag'] = 3.14,
}:processArgs(arg)

CONSOLE

Boolean
luajit program.lua --boolean_flag
luajit program.lua --noboolean_flag
luajit program.lua --boolean_flag=true
luajit program.lua --boolean_flag=false

String
luajit program.lua --string_flag="text here"
luajit program.lua --string_flag "text here"

Numerical
luajit program.lua --numerical_flag=3.14
luajit program.lua --numerical_flag 3.14


]]

local idx = {}
local mt = {__index = idx}

function idx:registerFlag(name, value)
  if self.flags[name] ~= nil then
    error('Name overlap: flag \'' .. name .. '\' already exists')
  end
  self.flags[name] = value;
  return self
end

function idx:registerFlags(flags)
  for k, v in pairs(flags) do
    self:registerFlag(k, v)
  end
  return self
end

function idx:add(flagOrFlags, value)
  if value ~= nil then
    return self:registerFlag(flagOrFlags, value)
  else
    return self:registerFlags(flagOrFlags)
  end
end

mt.__call = idx.add

local function setFlag(self, flags, flag, value)
  if self.flags[flag] ~= nil then
    if type(self.flags[flag]) == 'string' then
      flags[flag] = value
    elseif type(self.flags[flag]) == 'number' then
      flags[flag] = tonumber(value)
    else
      if value:lower() == 'false' then
        flags[flag] = false
      elseif value:lower() == 'true' then
        flags[flag] = true
      end
    end
  end
end

local function setBoolean(self, flags, flag)
  if self.flags[flag] ~= nil and type(self.flags[flag]) == 'boolean' then
      flags[flag] = true
      return ''
  else
    local noflag = flag:match '^no(.+)'
    if self.flags[noflag] ~= nil and type(self.flags[noflag]) == 'boolean' then
      flags[noflag] = false
      return ''
    end
  end
  return flag
end

function idx:processArgs(args)
  local flags = setmetatable({}, {__index=self.flags})

  local currentFlag = ''

  for i=1,#args do
    if currentFlag == '' then
      local flag, value = args[i]:match '^%-%-([^\t\r\n =]+)=(.+)'
      if flag then
        setFlag(self, flags, flag, value)
      else
        flag = args[i]:match '^%-%-([^\t\r\n =]+)'
        if flag then
          currentFlag = setBoolean(self, flags, flag)
        end
      end
    else
      setFlag(self, flags, currentFlag, args[i])
      currentFlag = ''
    end
  end
  
  self.defaultFlags = self.flags
  self.flags = flags
  return flags
end

local function new(flags)
  return setmetatable({flags=flags or {}}, mt)
end

return setmetatable({global = new()},
    {__call = function(s, ...) return new(...) end})

