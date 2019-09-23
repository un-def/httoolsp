local _M = {
  _VERSION = '0.1.1',
  _DESCRIPTION = 'A collection of HTTP-related pure Lua helper functions',
  _AUTHOR = 'un.def <me@undef.im>',
  _LICENSE = 'MIT License',
  _URL = 'https://github.com/un-def/httoolsp',
}

local str_sub = string.sub
local str_find = string.find
local str_gmatch = string.gmatch
local str_gsub = string.gsub
local str_lower = string.lower

local str_count = function(s, pattern, i, j)
  if i then
    s = str_sub(s, i, j)
  end
  local count = 0
  for _ in str_gmatch(s, pattern) do
    count = count + 1
  end
  return count
end

local str_strip = function(s)
  return str_gsub(s, '^%s*(.-)%s*$', '%1')
end

local split_iter = function(header, remainder)
  -- Splits a semicolon-separated string (such as MIME header).
  -- Returns a pair (remainder, value) on each call.
  -- The remainder serves as a control variable and should be ignored.
  if not remainder then
    -- first iteration
    remainder = header
  elseif remainder == '' then
    -- last iteration
    return nil
  end
  local idx = str_find(remainder, ';', 1, true)
  while idx and (str_count(remainder, [["]], 1, idx - 1) - str_count(remainder, [[\"]], 1, idx - 1)) % 2 > 0 do
    idx = str_find(remainder, ';', idx + 1, true)
  end
  local value
  if not idx then
    value = str_strip(remainder)
    remainder = ''
  else
    value = str_strip(str_sub(remainder, 1, idx - 1))
    remainder = str_sub(remainder, idx + 1)
  end
  return remainder, value
end

_M.parse_header = function(header)
  -- Parse a header into a main value and a table of parameters.
  -- This function is partially based on `cgi.parse_header` from CPython.
  local params = {}
  local remainder, value = split_iter(header)
  for _, p in split_iter, header, remainder do
    local i = str_find(p, '=', 1, true)
    if i then
      local pname = str_lower(str_strip(str_sub(p, 1, i - 1)))
      local pvalue = str_strip(str_sub(p, i + 1))
      if #pvalue >= 2 and str_sub(pvalue, 1, 1) == '"' and str_sub(pvalue, -1, -1) == '"' then
        pvalue = str_sub(pvalue, 2, -2)
        pvalue = str_gsub(str_gsub(pvalue, [[\\]], [[\]]), [[\"]], [["]])
      end
      params[pname] = pvalue
    end
  end
  return value, params
end

return _M
