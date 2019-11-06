str_byte = string.byte
str_format = string.format
str_gsub = string.gsub

_tohex_cb = (c) -> str_format '%02x', str_byte c

tohex = (bytes) ->
    hex = str_gsub bytes, '.', _tohex_cb
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

random_hex = (length) -> tohex random_bytes length


:random_bytes, :random_hex
