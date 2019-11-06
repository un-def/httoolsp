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


class FormData

    new: =>
        @_boundary = nil
        @_names = {}
        @_items = {}
        @_last_free_item_index = 1
        @_iterated = false
        @_rendered = nil

    get_boundary: =>
        boundary = @_boundary
        if boundary
            return boundary
        boundary = '====FormData=Boundary====%s===='\format random_hex 16
        @_boundary = boundary
        return boundary

    set_boundary: (boundary) =>
        if @_boundary
            return false, 'boundary is already set'
        if type(boundary) ~= 'string' or #boundary == 0 or #boundary > 70
            return false, 'boundary must be a non-empty string no longer than 70 characters'
        @_boundary = boundary
        return true

    count: =>
        count = 0
        for _, item_indexes in pairs @_names
            count += #item_indexes
        return count

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

    set: (name, value, content_type, filename) =>
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

    add: (name, value, content_type, filename) =>
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

    delete: (name) =>
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
        if priming
            callback nil
        boundary = @get_boundary!
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


:FormData, new: (...) -> FormData(...)
