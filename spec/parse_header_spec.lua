local parse_header = require('httoolsp').parse_header


local table_unpack = table.unpack or unpack


local tests = {
  -- original tests from Python
  {
    'text/plain',
    'text/plain', {},
  },
  {
    'text/vnd.just.made.this.up ; ',
    'text/vnd.just.made.this.up', {},
  },
  {
    'text/plain;charset=us-ascii',
    'text/plain', {charset = 'us-ascii'},
  },
  {
    'text/plain ; charset="us-ascii"',
    'text/plain', {charset = 'us-ascii'},
  },
  {
    'text/plain ; charset="us-ascii"; another=opt',
    'text/plain', {charset = 'us-ascii', another = 'opt'},
  },
  {
    'attachment; filename="silly.txt"',
    'attachment', {filename = 'silly.txt'},
  },
  {
    'attachment; filename="strange;name"',
    'attachment', {filename = 'strange;name'},
  },
  {
    'attachment; filename="strange;name";size=123;',
    'attachment', {filename = 'strange;name', size = '123'},
  },
  {
    'form-data; name="files"; filename="fo\\"o;bar"',
    'form-data', {name = 'files', filename = 'fo"o;bar'},
  },
  -- extra tests
  {
    'text/vnd.example.CUSTOM; CHARSET=utf-8',
    'text/vnd.example.CUSTOM', {charset = 'utf-8'},
  },
  {
    ' attachment\t;; ; filename="silly.txt"; foo;bar; size=123;baz;;; ',
    'attachment', {filename = 'silly.txt', size = '123'},
  },
}


describe('parse_header', function()
  for _, test in ipairs(tests) do
    local header, expected_value, expected_params = table_unpack(test)
    it(header, function()
      local value, params = parse_header(header)
      assert.are.equal(expected_value, value)
      assert.are.same(expected_params, params)
    end)
  end
end)
