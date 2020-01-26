local is_empty_table
is_empty_table = require('httoolsp.utils').is_empty_table
local str_sub = string.sub
local str_find = string.find
local str_gmatch = string.gmatch
local str_gsub = string.gsub
local str_lower = string.lower
local str_count
str_count = function(s, pattern, i, j)
  if i then
    s = str_sub(s, i, j)
  end
  local count = 0
  for _ in str_gmatch(s, pattern) do
    count = count + 1
  end
  return count
end
local str_strip
str_strip = function(s)
  return str_gsub(s, '^%s*(.-)%s*$', '%1')
end
local table_insert = table.insert
local table_concat = table.concat
local table_sort = table.sort
local _parse_header_iter
_parse_header_iter = function(header, remainder)
  if not remainder then
    remainder = header
  elseif remainder == '' then
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
local parse_header
parse_header = function(header)
  local params = { }
  local remainder, value = _parse_header_iter(header)
  for _, p in _parse_header_iter,header,remainder do
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
local _MEDIA_TYPE_PATTERN = '^[%w!#$&^_.+-]+$'
local _parse_media_type
_parse_media_type = function(media_type)
  local type_, subtype = media_type:match('^([^/]+)/([^/]+)$')
  if not type_ then
    return nil
  end
  if type_ == '*' and subtype ~= '*' then
    return nil
  end
  if type_ ~= '*' and not type_:match(_MEDIA_TYPE_PATTERN) then
    return nil
  end
  if subtype ~= '*' and not subtype:match(_MEDIA_TYPE_PATTERN) then
    return nil
  end
  return type_, subtype
end
local _media_types_sorter
_media_types_sorter = function(i, j)
  return i[1] > j[1]
end
local _empty_params_to_nil
_empty_params_to_nil = function(params)
  if is_empty_table(params) then
    return nil
  end
  return params
end
local __compare_params
__compare_params = function(params1, params2)
  for k, v in pairs(params1) do
    if v ~= params2[k] then
      return false
    end
  end
  return true
end
local _compare_params
_compare_params = function(params1, params2)
  if not params1 then
    if params2 then
      return false
    end
    return true
  end
  if not params2 then
    return false
  end
  if not __compare_params(params1, params2) then
    return false
  end
  return __compare_params(params2, params1)
end
local AcceptHeader
do
  local _class_0
  local _base_0 = {
    __tostring = function(self)
      if not self._header then
        local list = { }
        local _list_0 = self._media_types
        for _index_0 = 1, #_list_0 do
          local _des_0 = _list_0[_index_0]
          local weight, type_, subtype, params
          weight, type_, subtype, params = _des_0[1], _des_0[2], _des_0[3], _des_0[4]
          local item = {
            ('%s/%s'):format(type_, subtype)
          }
          if params then
            for k, v in pairs(params) do
              table_insert(item, ('%s=%s'):format(k, v))
            end
          end
          if weight ~= 1 then
            table_insert(item, ('q=%s'):format(weight))
          end
          table_insert(list, table_concat(item, ';'))
        end
        self._header = table_concat(list, ',')
      end
      return self._header
    end,
    get_weight = function(self, media_type)
      local params
      media_type, params = parse_header(media_type)
      local type_, subtype = _parse_media_type(media_type)
      if not type_ then
        return nil, 'invalid media type'
      end
      params = _empty_params_to_nil(params)
      local _list_0 = self._media_types
      for _index_0 = 1, #_list_0 do
        local _des_0 = _list_0[_index_0]
        local weight, c_type, c_subtype, c_params
        weight, c_type, c_subtype, c_params = _des_0[1], _des_0[2], _des_0[3], _des_0[4]
        if (c_type == '*' or c_type == type_) and (c_subtype == '*' or c_subtype == subtype) and _compare_params(params, c_params) then
          return weight
        end
      end
      return nil
    end,
    negotiate = function(self, media_types)
      local candidates = { }
      for _index_0 = 1, #media_types do
        local media_type = media_types[_index_0]
        local weight = self:get_weight(media_type)
        if weight then
          table_insert(candidates, {
            weight,
            media_type
          })
        end
      end
      table_sort(candidates, _media_types_sorter)
      local best = candidates[1]
      if not best then
        return nil
      end
      return best[2], best[1]
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, media_types)
      local _media_types = { }
      for _index_0 = 1, #media_types do
        local _des_0 = media_types[_index_0]
        local weight, type_, subtype, params
        weight, type_, subtype, params = _des_0[1], _des_0[2], _des_0[3], _des_0[4]
        if not weight then
          weight = 1
        end
        if params then
          params = _empty_params_to_nil(params)
        end
        table_insert(_media_types, {
          weight,
          type_,
          subtype,
          params
        })
      end
      table_sort(_media_types, _media_types_sorter)
      self._media_types = _media_types
    end,
    __base = _base_0,
    __name = "AcceptHeader"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  AcceptHeader = _class_0
end
local parse_accept_header
parse_accept_header = function(header, strict)
  if strict == nil then
    strict = false
  end
  header = str_strip(header)
  if strict and not header:match('^[%p%w ]*$') then
    return nil, 'invalid characters in header'
  end
  local media_types = { }
  for media_range in header:gmatch('[^%c,]+') do
    local weight, type_, subtype
    local media_type, params = parse_header(media_range)
    if #media_type > 1 then
      type_, subtype = _parse_media_type(media_type)
      if type_ then
        weight = params.q
        if weight then
          params.q = nil
          weight = tonumber(weight)
          if weight and (weight < 0 or weight > 1) then
            weight = nil
          end
          if not weight then
            if strict then
              return nil, ("invalid weight: '%s'"):format(str_strip(media_range))
            end
            weight = 0.01
          end
        end
        table_insert(media_types, {
          weight,
          type_,
          subtype,
          params
        })
      elseif strict then
        return nil, ("invalid media type: '%s'"):format(media_type)
      end
    elseif strict then
      return nil, ("empty media type: '%s'"):format(str_strip(media_range))
    end
  end
  return AcceptHeader(media_types)
end
return {
  parse_header = parse_header,
  parse_accept_header = parse_accept_header
}
