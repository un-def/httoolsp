str_byte = string.byte
str_format = string.format
str_gsub = string.gsub


is_empty_table = (tbl) -> next(tbl) == nil


_to_hex_cb = (c) -> str_format '%02x', str_byte c

to_hex = (bytes) ->
    hex = str_gsub bytes, '.', _to_hex_cb
    return hex


_get_random_function = () ->
    -- OpenResty
    ok, mod = pcall require, 'resty.random'
    if ok and mod.bytes
        return mod.bytes
    -- Tarantool
    ok, mod = pcall require, 'digest'
    if ok and mod.urandom
        return mod.urandom
    -- fallback implementation
    str_char = string.char
    math_random = math.random
    return (length) ->
        t = {}
        for n = 1, length
            t[n] = str_char math_random 1, 255
        return table.concat(t)

random_bytes = _get_random_function!

random_hex = (length) -> to_hex random_bytes length


:is_empty_table, :to_hex, :random_bytes, :random_hex
