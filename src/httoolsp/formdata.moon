--- Submodule for `multipart/form-data` manipulation
-- @module httoolsp.formdata
import random_hex from require 'httoolsp.utils'


table_insert = table.insert
table_concat = table.concat
co_wrap = coroutine.wrap
co_yield = coroutine.yield


DEFAULT_CONTENT_TYPE = 'application/octet-stream'
CRLF = '\r\n'


_check_value_type = (value) ->
    value_type = type value
    if value_type == 'string' or value_type == 'function'
        return true
    return false, 'value %s has unsupported type %s'\format tostring(value), value_type

_check_param_type = (param_name, param) ->
    if type(param) == 'string'
        return true
    if param_name == 'name'
        return false, 'name parameter must be a string'
    if param == nil
        return true
    return false, '%s parameter must be a string or nil'\format param_name

_make_item = (name, value, content_type, filename) ->
    ok, err = _check_param_type 'name', name
    if not ok
        return nil, err
    ok, err = _check_value_type value
    if not ok
        return nil, err
    ok, err = _check_param_type 'content_type', content_type
    if not ok
        return nil, err
    ok, err = _check_param_type 'filename', filename
    if not ok
        return nil, err
    if filename
        if not content_type
            content_type = DEFAULT_CONTENT_TYPE
        return {name, value, content_type, filename}
    elseif content_type
        return {name, value, content_type}
    return {name, value}

_item_to_value = (item) -> item[2]

_item_to_table = (item) ->
    return {
        name: item[1]
        value: item[2]
        content_type: item[3]
        filename: item[4]
    }


--- A class representing `multipart/form-data`.
-- @type FormData
class FormData

    new: =>
        @_boundary = nil
        @_names = {}
        @_items = {}
        @_last_free_item_index = 1
        @_iterated = false
        @_rendered = nil

    --- Get boundary value.
    -- Generates random boundary if not set.
    -- @treturn string boundary
    get_boundary: =>
        boundary = @_boundary
        if boundary
            return boundary
        boundary = '====FormData=Boundary====%s===='\format random_hex 16
        @_boundary = boundary
        return boundary

    --- Set boundary value.
    -- Returns error if boundary is already set.
    -- @tparam string boundary
    -- @treturn[1] bool true
    -- @treturn[2] bool false
    -- @treturn[2] string error message
    set_boundary: (boundary) =>
        if @_boundary
            return false, 'boundary is already set'
        if type(boundary) ~= 'string' or #boundary == 0 or #boundary > 70
            return false, 'boundary must be a non-empty string no longer than 70 characters'
        @_boundary = boundary
        return true

    --- Get the count of form-data parts.
    -- @treturn int
    count: =>
        count = 0
        for _, item_indexes in pairs @_names
            count += #item_indexes
        return count

    --- Get the value of a form-data part with the specified name.
    -- Returns the value or the _value table_ depending on `as_table` parameter.
    --
    -- _Value table_ is a hash table with the following fields:
    --
    -- * `name`: part name, `string`
    -- * `value`: part value, `string` or iterator `function`
    -- * `content_type`: part media type, `string` or `nil`
    -- * `filename`: part filename, `string` or `nil`
    --
    -- If there is more than one part with the specified name, the value of the only first or last part
    -- will be returned depending on `last` parameter.
    -- @tparam string name part name
    -- @tparam ?bool last get the value of the last part instead of the first if `true` (default is `false`)
    -- @tparam ?bool as_table return the value as a _value table_ if `true` (default is `false`)
    -- @treturn[1] string|function value
    -- @treturn[2] table _value table_
    -- @treturn[3] nil
    -- @treturn[3] string error message
    get: (name, last=false, as_table=false) =>
        ok, err = _check_param_type 'name', name
        if not ok
            return nil, err
        item_indexes = @_names[name]
        if not item_indexes
            return nil
        local item_index
        if last
            item_index = item_indexes[#item_indexes]
        else
            item_index = item_indexes[1]
        item = @_items[item_index]
        if as_table
            return _item_to_table item
        return _item_to_value item

    --- Get all values of form-data parts with the specified name.
    -- Returns an array of values or _value tables_ depending on `as_table` parameter.
    -- @tparam string name part name
    -- @tparam ?bool as_table return the values as _value tables_ if `true` (default is `false`)
    -- @treturn[1] table array of values or _value tables_
    -- @treturn[2] nil
    -- @treturn[2] string error message
    get_all: (name, as_table=false) =>
        ok, err = _check_param_type 'name', name
        if not ok
            return nil, err
        item_indexes = @_names[name]
        if not item_indexes
            return nil
        items = @_items
        local extractor
        if as_table
            extractor = _item_to_table
        else
            extractor = _item_to_value
        return [extractor items[idx] for idx in *item_indexes]

    --- Add form-data part discarding existing parts with the same name (if any).
    -- @tparam string name part name
    -- @tparam string|function value part value
    -- @tparam ?string content_type part media type
    -- @tparam ?string filename part filename
    -- @treturn[1] true
    -- @treturn[2] false
    -- @treturn[2] string error message
    set: (name, value, content_type, filename) =>
        ok, err = @_check_mutable!
        if not ok
            return false, err
        item, err = _make_item name, value, content_type, filename
        if not item
            return false, err
        local item_index
        old_item_indexes = @_names[name]
        if old_item_indexes
            for old_item_index in *old_item_indexes
                @_items[old_item_index] = nil
            item_index = old_item_indexes[1]
        else
            item_index = @_last_free_item_index
            @_last_free_item_index = item_index + 1
        @_items[item_index] = item
        @_names[name] = {item_index}
        return true

    --- Add form-data part keeping existing parts with the same name.
    -- @tparam string name part name
    -- @tparam string|function value part value
    -- @tparam ?string content_type part media type
    -- @tparam ?string filename part filename
    -- @treturn[1] true
    -- @treturn[2] false
    -- @treturn[2] string error message
    add: (name, value, content_type, filename) =>
        ok, err = @_check_mutable!
        if not ok
            return false, err
        item, err = _make_item name, value, content_type, filename
        if not item
            return false, err
        item_index = @_last_free_item_index
        @_last_free_item_index = item_index + 1
        @_items[item_index] = item
        item_indexes = @_names[name]
        if item_indexes
            table_insert item_indexes, item_index
        else
            @_names[name] = {item_index}
        return true

    --- Delete part(s) with the specified name.
    -- @tparam string name part name
    -- @treturn[1] int count of deleted parts, > 0
    -- @treturn[2] nil if no part found
    -- @treturn[3] nil
    -- @treturn[3] string error message
    delete: (name) =>
        ok, err = @_check_mutable!
        if not ok
            return nil, err
        ok, err = _check_param_type 'name', name
        if not ok
            return nil, err
        item_indexes = @_names[name]
        if not item_indexes
            return nil
        @_names[name] = nil
        for item_index in *item_indexes[#item_indexes, 1, -1]
            @_items[item_index] = nil
            if item_index + 1 == @_last_free_item_index
                @_last_free_item_index -= 1
        return #item_indexes

    _check_mutable: () =>
        if @_iterated
            return false, 'form-data is already iterated, cannot mutate'
        if @_rendered
            return false, 'form-data is already rendered, cannot mutate'
        return true

    --- Render form-data content to string.
    -- @treturn[1] string rendered form-data
    -- @treturn[2] nil
    -- @treturn[2] string error message
    render: =>
        rendered = @_rendered
        if rendered
            return rendered
        if @_iterated
            return nil, 'form-data is already iterated, cannot render'
        if @count! == 0
            return nil, 'empty form-data'
        buffer = {}
        @_render (chunk) -> table_insert buffer, chunk
        rendered = table_concat buffer
        @_rendered = rendered
        return rendered

    --- Get iterator function rendering form-data content.
    -- @treturn[1] function iterator
    -- @treturn[2] nil
    -- @treturn[2] string error message
    iterator: =>
        if @_iterated
            return nil, 'form-data is already iterated, cannot iterate again'
        if @_rendered
            return nil, 'form-data is already rendered, cannot iterate'
        if @count! == 0
            return nil, 'empty form-data'
        @_iterated = true
        co = co_wrap @_render
        co @, co_yield, true
        return co

    _render: (callback, priming=false) =>
        boundary = @get_boundary!
        if priming
            callback nil
        sep = '--%s'\format boundary
        for idx = 1, @_last_free_item_index - 1
            item = @_items[idx]
            if item
                {name, value, content_type, filename} = item
                chunk = {sep}
                if filename
                    table_insert chunk,
                        'content-disposition: form-data; name="%s"; filename="%s"'\format name, filename
                else
                    table_insert chunk, 'content-disposition: form-data; name="%s"'\format name
                if content_type
                    table_insert chunk, 'content-type: %s'\format content_type
                if type(value) == 'string'
                    table_insert chunk, CRLF .. value
                    callback table_concat(chunk, CRLF) .. CRLF
                else
                    callback table_concat(chunk, CRLF) .. CRLF .. CRLF
                    for c in value
                        callback c
                    callback CRLF
        callback '--%s--%s'\format boundary, CRLF

--- @section end

--- Shortcut for `FormData` constructor.
-- @treturn FormData FormData instance
new = () -> FormData()


:FormData, :new
