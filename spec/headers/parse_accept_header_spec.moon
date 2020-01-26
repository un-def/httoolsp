import parse_accept_header from require 'httoolsp.headers'


describe 'parse_accept_header', ->

    tests = {
        {
            'text/plain,\ntext/*;q=.8, text/html;q=.3;foo=bar'
            'invalid characters in header'
            'text/plain,text/*;q=0.8,text/html;foo=bar;q=0.3'
        }
        {
            'text/plain,   ;q=.8,  application/json; q=0.3'
            "empty media type: ';q=.8'"
            'text/plain,application/json;q=0.3'
        }
        {
            'text/plain;q=.8,  foobar; q=.3, text/html;q=1.0'
            "invalid media type: 'foobar'"
            'text/html,text/plain;q=0.8'
        }
        {   'text/plain;q=.8,  image/jpeg; q=e, text/html'
            "invalid weight: 'image/jpeg; q=e'"
            'text/html,text/plain;q=0.8,image/jpeg;q=0.01'
        }
        {
            '  text/plain;q=.8,  image/jpeg; q=1.1, text/html  '
            "invalid weight: 'image/jpeg; q=1.1'"
            'text/html,text/plain;q=0.8,image/jpeg;q=0.01'
        }
        {
            'text/*;q=.8,  image/jpeg; q=-3, text/html;q=1'
            "invalid weight: 'image/jpeg; q=-3'"
            'text/html,text/*;q=0.8,image/jpeg;q=0.01'
        }
    }

    describe 'should return error in strict mode', ->
        for {header, expected_error} in *tests
            it expected_error, ->
                value, error = parse_accept_header header, true
                assert.is.nil value
                assert.are.equal expected_error, error

    describe 'should ignore malformed data in non-strict mode', ->
        for {header, _, expected} in *tests
            it expected, ->
                value, error = parse_accept_header header
                assert.is.nil error
                assert.is.equal expected, tostring value


describe 'AcceptHeader', ->

    header = 'text/html, text/*;q=.8,text/plain;q=.9, application/json;foo=1;bar=value;q=.5'

    local accept_header
    before_each ->
        accept_header = parse_accept_header header

    describe 'get_weight', ->

        describe 'should return weight if media type found', ->
            tests = {
                {'text/html', 1}
                {'text/vnd.foo', .8}
                {'text/plain', .9}
                {'application/json; bar="value"; foo=1', .5}
            }
            for {media_type, expected_weight} in *tests
                it media_type, ->
                    weight = accept_header\get_weight media_type
                    assert.are.equal expected_weight, weight

        describe 'should return nil media type not found', ->
            tests = {
                'image/jpeg'
                'application/vnd.foo'
                'application/json; bar=value; foo=2'
                'application/json; bar=value;'
                'application/json; foo=1'
                'application/json; foo=1; bar=value; baz=2'
            }
            for media_type in *tests
                it media_type, ->
                    weight = accept_header\get_weight media_type
                    assert.is.nil weight

    describe 'negotiate', ->

        describe 'should return media type and weight if media type found', ->
            tests = {
                {{'text/vnd.foo', 'text/html', 'image/png'}, 'text/html', 1}
                {{'image/png', 'text/vnd.foo'}, 'text/vnd.foo', .8}
                {{'text/vnd.foo', 'application/json', 'text/plain'}, 'text/plain', .9}
            }
            for {media_types, expected_media_type, expected_weight} in *tests
                it expected_media_type, ->
                    media_type, weight = accept_header\negotiate media_types
                    assert.are.equal expected_media_type, media_type
                    assert.are.equal expected_weight, weight

        describe 'should return nil if media type not found', ->
            tests = {
                {}
                {'image/png', 'application/vnd.bar'}
                {'image/webp', 'application/json;foo=2;bar=value'}
            }
            for media_types in *tests
                it ->
                    media_type, weight = accept_header\negotiate media_types
                    assert.is.nil media_type
                    assert.is.nil weight
