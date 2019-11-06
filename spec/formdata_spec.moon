formdata = require 'httoolsp.formdata'


NIL = {}

ERR_INVALID = {
    name: 'name parameter must be a string'
    content_type: 'content_type parameter must be a string or nil'
    filename: 'filename parameter must be a string or nil'
}

INVALID_VALUES = {
    [12]: 'value 12 has unsupported type number'
    [false]: 'value false has unsupported type boolean'
    [NIL]: 'value nil has unsupported type nil'
    [{'foo', 1}]: 'value table: 0xdeadbeef has unsupported type table'
}

ADD_SET_PARAMS = {
    'name'
    'value'
    'content_type'
    'filename'
}


join = table.concat

unpack = table.unpack or unpack

prepare_add_set_params = () -> {'field', 'foobar', 'text/plain', 'file.txt'}

get_value_iterator = (count_from, count_to) ->
    count = count_from
    return () ->
        if count > count_to
            return nil
        count += 1
        return '{%s}'\format count - 1


local fd


before_each ->
    fd = formdata.new!


describe 'get_boundary', ->

    it 'should generate boundary on first request', ->
        assert.is.nil fd._boundary
        boundary = fd\get_boundary!
        assert.is.equal 'string', type boundary
        assert.is.equal boundary, fd\get_boundary!


describe 'set_boundary', ->

    err_invalid = 'boundary must be a non-empty string no longer than 70 characters'
    err_already_set = 'boundary is already set'

    it 'should accept only strings', ->
        ok, err = fd\set_boundary 123
        assert.is.false ok
        assert.is.equal err_invalid, err

    it 'should not accept empty string', ->
        ok, err = fd\set_boundary ''
        assert.is.false ok
        assert.is.equal err_invalid, err

    it 'should not accept string longer than 70 chars', ->
        ok, err = fd\set_boundary string.rep '#', 71
        assert.is.false ok
        assert.is.equal err_invalid, err

    describe 'should not allow to set boundary in it is already set', ->

        it 'explicitly', ->
            fd\set_boundary 'BNDR'
            ok, err = fd\set_boundary 'BNDRNEW'
            assert.is.false ok
            assert.is.equal err_already_set, err

        it 'implicitly', ->
            fd\get_boundary!
            ok, err = fd\set_boundary 'BNDRNEW'
            assert.is.false ok
            assert.is.equal err_already_set, err


describe 'get', ->

    it 'should check name type', ->
        value, err = fd\get 123
        assert.is.nil value
        assert.is.equal ERR_INVALID.name, err

    it 'should return nil if the field is not found', ->
        fd\set 'field1', 'foo'
        value, err = fd\get 'field2'
        assert.is.nil value
        assert.is.nil err
        value, err = fd\get 'field2', false, true
        assert.is.nil value
        assert.is.nil err

    it 'should return the first value by default', ->
        for value in *{'foo', 'bar', 'baz'}
            fd\add 'field1', value
        fd\add 'field1', 'qux', nil, 'qux.bin'
        assert.is.equal 'foo', fd\get 'field1'
        assert.is.same {name: 'field1', value: 'foo'}, fd\get 'field1', nil, true

    it 'should return the first value if last = false', ->
        for value in *{'foo', 'bar', 'baz'}
            fd\add 'field1', value
        fd\add 'field1', 'qux', nil, 'qux.bin'
        assert.is.equal 'foo', fd\get 'field1', false
        assert.is.same {name: 'field1', value: 'foo'}, fd\get 'field1', false, true

    it 'should return the last value if last = true', ->
        for value in *{'foo', 'bar', 'baz'}
            fd\add 'field1', value
        fd\add 'field1', 'qux', nil, 'qux.bin'
        assert.is.equal 'qux', fd\get 'field1', true
        assert.is.same {
            name: 'field1', value: 'qux'
            content_type: 'application/octet-stream', filename: 'qux.bin'
        }, fd\get 'field1', true, true

    it 'should return the same value if there is only one value', ->
        fd\set 'field1', 'bar', 'text/plain'
        assert.is.equal 'bar', fd\get 'field1', false
        assert.is.equal 'bar', fd\get 'field1', true
        expected_table = {name: 'field1', 'value': 'bar', content_type: 'text/plain'}
        assert.is.same expected_table, fd\get 'field1', false, true
        assert.is.same expected_table, fd\get 'field1', true, true


describe 'get_all', ->

    it 'should check name type', ->
        value, err = fd\get_all {1}
        assert.is.nil value
        assert.is.equal ERR_INVALID.name, err

    it 'should return nil if the field is not found', ->
        fd\set 'field1', 'foo'
        value, err = fd\get_all 'field2'
        assert.is.nil value
        assert.is.nil err
        value, err = fd\get_all 'field2', true
        assert.is.nil value
        assert.is.nil err

    it 'should return all values in the same order', ->
        fd\set 'field1', 'bar', 'text/plain'
        fd\set 'field2', 'foo', nil, 'binary'
        fd\add 'field1', 'qux'
        fd\add 'field1', 'baz', 'text/html', 'index.html'
        assert.is.same {'bar', 'qux', 'baz'}, fd\get_all 'field1'
        assert.is.same {
            {name: 'field1', value: 'bar', content_type: 'text/plain'}
            {name: 'field1', value: 'qux'}
            {name: 'field1', value: 'baz', content_type: 'text/html', filename: 'index.html'}
        }, fd\get_all 'field1', true


describe 'set', ->

    describe 'should check param type', ->
        for pos, param_name in ipairs ADD_SET_PARAMS
            if param_name == 'value'
                continue
            it param_name, ->
                params = prepare_add_set_params!
                params[pos] = 123
                ok, err = fd\set unpack params
                assert.is.false ok
                assert.is.equal ERR_INVALID[param_name], err

    describe 'should check value type', ->
        for value, expected_err in pairs INVALID_VALUES
            if value == NIL
                value = nil
            it tostring(value), ->
                ok, err = fd\set 'field', value
                assert.is.false ok
                err = err\gsub '0x%x+', '0xdeadbeef', 1
                assert.is.equal expected_err\format(value), err

    it 'should set a new value', ->
        ok, err = fd\set 'field', 'foo'
        assert.is.true ok
        assert.is.nil err
        assert.is.same {'foo'}, fd\get_all 'field'

    it 'should overwrite an existing value', ->
        fd\set 'field', 'foo'
        ok, err = fd\set 'field', 'bar'
        assert.is.true ok
        assert.is.nil err
        assert.is.same {'bar'}, fd\get_all 'field'

    it 'should accept a function as a value', ->
        fn = () ->
        ok, err = fd\set 'field', fn
        assert.is.true ok
        assert.is.nil err
        assert.is.same {fn}, fd\get_all 'field'


describe 'add', ->

    describe 'should check param type', ->
        for pos, param_name in ipairs ADD_SET_PARAMS
            if param_name == 'value'
                continue
            it param_name, ->
                params = prepare_add_set_params!
                params[pos] = 123
                ok, err = fd\set unpack params
                assert.is.false ok
                assert.is.equal ERR_INVALID[param_name], err

    describe 'should check value type', ->
        for value, expected_err in pairs INVALID_VALUES
            if value == NIL
                value = nil
            it tostring(value), ->
                ok, err = fd\add 'field', value
                assert.is.false ok
                err = err\gsub '0x%x+', '0xdeadbeef', 1
                assert.is.equal expected_err\format(value), err

    it 'should set a new value', ->
        ok, err = fd\add 'field', 'foo'
        assert.is.true ok
        assert.is.nil err
        assert.is.same {'foo'}, fd\get_all 'field'

    it 'should append to existing value(s)', ->
        fd\add 'field1', 'bar'
        fd\add 'field2', 'qux'
        ok, err = fd\add 'field1', 'foo'
        assert.is.true ok
        assert.is.nil err
        assert.is.same {'bar', 'foo'}, fd\get_all 'field1'

    it 'should accept a function as a value', ->
        fn = () ->
        ok, err = fd\add 'field', fn
        assert.is.true ok
        assert.is.nil err
        assert.is.same {fn}, fd\get_all 'field'


describe 'count', ->

    it 'should return value count', ->
        assert.is.equal 0, fd\count!
        fd\set 'field1', 'foo'
        assert.is.equal 1, fd\count!
        for value in *{'bar', 'baz'}
            fd\add 'field2', value
        assert.is.equal 3, fd\count!
        fd\set 'field1', 'qux'
        assert.is.equal 3, fd\count!
        for value in *{'foo', 'bar', 'baz'}
            fd\add 'field1', value
        assert.is.equal 6, fd\count!
        fd\delete 'field2'
        assert.is.equal 4, fd\count!
        fd\delete 'field1'
        assert.is.equal 0, fd\count!


describe 'delete', ->

    it 'should check name type', ->
        value, err = fd\delete true
        assert.is.nil value
        assert.is.equal ERR_INVALID.name, err

    it 'should delete value(s) by field name', ->
        assert.is.nil fd\delete 'nonexistent'
        fd\set 'field1', 'foo'
        fd\set 'field2', 'bar'
        fd\add 'field2', 'baz'
        assert.is.equal 2, fd\delete 'field2'
        assert.is.nil fd\get 'field2'
        assert.is.equal 1, fd\delete 'field1'
        assert.is.nil fd\get 'field1'
        assert.is.nil fd\delete 'field1'


describe 'render', ->

    before_each ->
        fd\set_boundary 'BOUNDARY'

    it 'should return error if form-data is empty', ->
        rendered, err = fd\render!
        assert.is.nil rendered
        assert.is.equal 'empty form-data', err
        fd\set 'field', 'foo'
        fd\delete 'field'
        rendered, err = fd\render!
        assert.is.nil rendered
        assert.is.equal 'empty form-data', err

    it 'should return error if form-data is already iterated', ->
        fd\set 'field', 'foo'
        fd\iterator!
        rendered, err = fd\render!
        assert.is.nil rendered
        assert.is.equal 'form-data is already iterated, cannot render', err

    it 'should render form-data', ->
        fd\set 'field1', 'bar\nBAR'
        value_iterator = get_value_iterator 3, 7
        fd\set 'field2', value_iterator, nil, 'foo.txt'
        fd\add 'field1', 'baz', 'text/html', 'index.html'
        expected = join {
            '--BOUNDARY\r\n'
            'content-disposition: form-data; name="field1"\r\n'
            '\r\n'
            'bar\nBAR\r\n'
            '--BOUNDARY\r\n'
            'content-disposition: form-data; name="field2"; filename="foo.txt"\r\n'
            'content-type: application/octet-stream\r\n'
            '\r\n'
            '{3}{4}{5}{6}{7}\r\n'
            '--BOUNDARY\r\n'
            'content-disposition: form-data; name="field1"; filename="index.html"\r\n'
            'content-type: text/html\r\n'
            '\r\n'
            'baz\r\n'
            '--BOUNDARY--\r\n'
        }
        rendered, err = fd\render!
        assert.is.equal expected, rendered
        assert.is.nil err
        -- subsequent renders return cached content
        rendered, err = fd\render!
        assert.is.equal expected, rendered
        assert.is.nil err


describe 'iterator', ->

    before_each ->
        fd\set_boundary 'BOUNDARY'

    it 'should return error if form-data is empty', ->
        iterator, err = fd\iterator!
        assert.is.nil iterator
        assert.is.equal 'empty form-data', err
        fd\set 'field', 'foo'
        fd\delete 'field'
        iterator, err = fd\iterator!
        assert.is.nil iterator
        assert.is.equal 'empty form-data', err

    it 'should return error if form-data is already rendered', ->
        fd\set 'field', 'foo'
        fd\render!
        iterator, err = fd\iterator!
        assert.is.nil iterator
        assert.is.equal 'form-data is already rendered, cannot iterate', err

    it 'should return error if form-data is already iterated', ->
        fd\set 'field', 'foo'
        fd\iterator!
        iterator, err = fd\iterator!
        assert.is.nil iterator
        assert.is.equal 'form-data is already iterated, cannot iterate again', err

    it 'should return iterator', ->
        fd\add 'field1', 'should'
        fd\add 'field1', 'be'
        fd\add 'field1', 'replaced'
        value_iterator = get_value_iterator 3, 5
        fd\set 'field2', value_iterator, nil, 'foo.txt'
        fd\set 'field1', 'bar\nBAR'
        fd\set 'field0', '', 'text/markdown'
        fd\add 'field1', 'baz', 'text/html', 'index.html'
        chunks = {
            join {
                '--BOUNDARY\r\n'
                'content-disposition: form-data; name="field1"\r\n'
                '\r\n'
                'bar\nBAR\r\n'
            }
            join {
                '--BOUNDARY\r\n'
                'content-disposition: form-data; name="field2"; filename="foo.txt"\r\n'
                'content-type: application/octet-stream\r\n'
                '\r\n'
            }
            '{3}'
            '{4}'
            '{5}'
            '\r\n'
            join {
                '--BOUNDARY\r\n'
                'content-disposition: form-data; name="field0"\r\n'
                'content-type: text/markdown\r\n'
                '\r\n'
                '\r\n'
            }
            join {
                '--BOUNDARY\r\n'
                'content-disposition: form-data; name="field1"; filename="index.html"\r\n'
                'content-type: text/html\r\n'
                '\r\n'
                'baz\r\n'
            }
            '--BOUNDARY--\r\n'
        }
        iterator, err = fd\iterator!
        assert.is.nil err
        assert.is.equal 'function', type iterator
        idx = 1
        for chunk in iterator
            assert.is.equal chunks[idx], chunk, idx
            idx += 1
