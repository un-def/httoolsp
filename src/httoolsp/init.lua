local _M = {}

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
  -- Splits passed line by semicolon.
  -- Returns a pair (remainder, value) on each call.
  -- Remainder serve as a state variable and should be ignored.
  if not remainder then
    -- first iteration
    remainder = header
  elseif str_sub(remainder, 1, 1) == ';' then
    remainder = str_sub(remainder, 2)
  else
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
    remainder = str_sub(remainder, idx)
  end
  return remainder, value
end

_M.parse_header = function(header)
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
