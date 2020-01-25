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


:parse_header
