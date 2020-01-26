import is_empty_table from require 'httoolsp.utils'


str_sub = string.sub
str_find = string.find
str_gmatch = string.gmatch
str_gsub = string.gsub
str_lower = string.lower

str_count = (s, pattern, i, j) ->
    if i
        s = str_sub(s, i, j)
    count = 0
    for _ in str_gmatch(s, pattern)
        count += 1
    return count

str_strip = (s) -> str_gsub(s, '^%s*(.-)%s*$', '%1')

table_insert = table.insert
table_concat = table.concat
table_sort = table.sort

---- parse_header ----

_parse_header_iter = (header, remainder) ->
    -- Splits a semicolon-separated string (such as MIME header).
    -- Returns a pair (remainder, value) on each call.
    -- The remainder serves as a control variable and should be ignored.
    if not remainder
        -- first iteration
        remainder = header
    elseif remainder == ''
        -- last iteration
        return nil
    idx = str_find(remainder, ';', 1, true)
    while idx and (str_count(remainder, [["]], 1, idx - 1) - str_count(remainder, [[\"]], 1, idx - 1)) % 2 > 0
        idx = str_find(remainder, ';', idx + 1, true)
    local value
    if not idx
        value = str_strip(remainder)
        remainder = ''
    else
        value = str_strip(str_sub(remainder, 1, idx - 1))
        remainder = str_sub(remainder, idx + 1)
    return remainder, value

parse_header = (header) ->
  -- Parse a header into a main value and a table of parameters.
  -- This function is partially based on `cgi.parse_header` from CPython.
    params = {}
    remainder, value = _parse_header_iter(header)
    for _, p in _parse_header_iter, header, remainder
        i = str_find(p, '=', 1, true)
        if i
            pname = str_lower(str_strip(str_sub(p, 1, i - 1)))
            pvalue = str_strip(str_sub(p, i + 1))
            if #pvalue >= 2 and str_sub(pvalue, 1, 1) == '"' and str_sub(pvalue, -1, -1) == '"'
                pvalue = str_sub(pvalue, 2, -2)
                pvalue = str_gsub(str_gsub(pvalue, [[\\]], [[\]]), [[\"]], [["]])
            params[pname] = pvalue
    return value, params

---- parse_accept_header ----

_MEDIA_TYPE_PATTERN = '^[%w!#$&^_.+-]+$'

_parse_media_type = (media_type) ->
    type_, subtype = media_type\match '^([^/]+)/([^/]+)$'
    if not type_
        return nil
    if type_ == '*' and subtype ~= '*' then
        return nil
    if type_ ~= '*' and not type_\match _MEDIA_TYPE_PATTERN
        return nil
    if subtype ~= '*' and not subtype\match _MEDIA_TYPE_PATTERN
        return nil
    return type_, subtype

_media_types_sorter = (i, j) -> i[1] > j[1]

_empty_params_to_nil = (params) ->
    if is_empty_table params
        return nil
    return params

__compare_params = (params1, params2) ->
    for k, v in pairs params1
        if v ~= params2[k]
            return false
    return true

_compare_params = (params1, params2) ->
    if not params1
        if params2
            return false
        return true
    if not params2
        return false
    if not __compare_params params1, params2
        return false
    return __compare_params params2, params1

class AcceptHeader

    new: (media_types) =>
        -- media types: array of arrays {weight, type, subtype, params}
        --      weight: number or nil
        --      type: string
        --      subtype: string
        --      params: table or nil
        _media_types = {}
        for {weight, type_, subtype, params} in *media_types
            if not weight
                weight = 1
            if params
                params = _empty_params_to_nil params
            table_insert _media_types, {weight, type_, subtype, params}
        table_sort _media_types, _media_types_sorter
        @_media_types = _media_types

    __tostring: () =>
        if not @_header
            list = {}
            for {weight, type_, subtype, params} in *@_media_types
                item = {
                    '%s/%s'\format(type_, subtype)
                }
                if params
                    for k, v in pairs params
                        table_insert item, '%s=%s'\format(k, v)
                if weight ~= 1
                    table_insert item, 'q=%s'\format(weight)
                table_insert list, table_concat item, ';'
            @_header = table_concat list, ','
        return @_header

    get_weight: (media_type) =>
        -- returns weight of passed media type or nil
        media_type, params = parse_header media_type
        type_, subtype = _parse_media_type media_type
        if not type_
            return nil, 'invalid media type'
        params = _empty_params_to_nil params
        for {weight, c_type, c_subtype, c_params} in *@_media_types
            if  (c_type == '*' or c_type == type_) and
                    (c_subtype == '*' or c_subtype == subtype) and
                    _compare_params(params, c_params)
                return weight
        return nil

    negotiate: (media_types) =>
        -- return "best" media type and its weight or nil
        candidates = {}
        for media_type in *media_types
            weight = @get_weight media_type
            if weight
                table_insert candidates, {weight, media_type}
        table_sort candidates, _media_types_sorter
        best = candidates[1]
        if not best
            return nil
        return best[2], best[1]

parse_accept_header = (header, strict=false) ->
    header = str_strip header
    if strict and not header\match '^[%g ]*$'
        return nil, 'invalid characters in header'
    media_types = {}
    for media_range in header\gmatch '[^%c,]+'
        local weight, type_, subtype
        media_type, params = parse_header(media_range)
        if #media_type > 1
            type_, subtype = _parse_media_type media_type
            if type_
                weight = params.q
                if weight
                    params.q = nil
                    weight = tonumber weight
                    if weight and (weight < 0 or weight > 1)
                        weight = nil
                    if not weight
                        if strict
                            return nil, "invalid weight: '%s'"\format str_strip media_range
                        -- set low weight for malformed values
                        weight = 0.01
                table_insert media_types, {weight, type_, subtype, params}
            elseif strict
                return nil, "invalid media type: '%s'"\format media_type
        elseif strict
            return nil, "empty media type: '%s'"\format str_strip media_range
    return AcceptHeader media_types


:parse_header, :parse_accept_header
