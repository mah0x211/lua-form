require('luacov')
local testcase = require('testcase')
local form = require('form')

local FILE = io.tmpfile()
FILE:close()

function testcase.is_valid_boundary()
    -- test that true
    assert(form.is_valid_boundary('foo-bar-baz'))

    -- test that return invalid character error
    local ok, err = form.is_valid_boundary('foo#bar-baz')
    assert.is_false(ok)
    assert.match(err, 'invalid character "#" found in boundary')

    -- test that throws an error if boundary is not string
    err = assert.throws(form.is_valid_boundary, {})
    assert.match(err, 'boundary must be string')
end

function testcase.new()
    -- test that create new form
    local f = form.new()
    assert.match(f, '^form: ', false)
end

function testcase.get()
    local f = form.new()
    assert(f:add('foo', 'bar'))
    assert(f:add('foo', 'baz'))
    assert(f:add('qux', 'baa'))
    assert(f:add('qux', {
        data = 'quux',
    }))
    assert(f:add('qux', {
        data = 'corge',
    }))
    assert(f:add('qux', {
        filename = 'hello.txt',
        pathname = 'hello.txt',
    }))
    assert(f:add('qux', {
        data = 'grault',
    }))
    assert(f:add('hello', {
        data = 'world',
    }))

    -- test that get a first value for key
    assert.equal(f:get('foo'), 'bar')
    assert.equal(f:get('qux'), 'baa')
    assert.equal(f:get('hello'), 'world')

    -- test that get values for key
    assert.equal(f:get('foo', true), {
        'bar',
        'baz',
    })
    assert.equal(f:get('qux', true), {
        'baa',
        'quux',
        'corge',
        'grault',
    })

    -- test that throws an error if key is invalid
    local err = assert.throws(f.get, f, 123)
    assert.match(err, 'key must be string')

    -- test that throws an error if all is invalid
    err = assert.throws(f.get, f, 'key', {})
    assert.match(err, 'all must be boolean')
end

function testcase.getraw()
    local f = form.new()
    assert(f:add('foo', 'bar'))
    assert(f:add('foo', 'baz'))
    assert(f:add('qux', 'baa'))
    assert(f:add('qux', {
        data = 'quux',
    }))
    assert(f:add('qux', {
        data = 'corge',
    }))
    assert(f:add('qux', {
        filename = 'hello.txt',
        pathname = 'hello.txt',
    }))
    assert(f:add('qux', {
        data = 'grault',
    }))

    -- test that get a first raw value for key
    assert.equal(f:getraw('foo'), 'bar')
    assert.equal(f:getraw('qux'), 'baa')

    -- test that get raw values for key
    assert.equal(f:getraw('foo', true), {
        'bar',
        'baz',
    })
    assert.equal(f:getraw('qux', true), {
        'baa',
        {
            data = 'quux',
        },
        {
            data = 'corge',
        },
        {
            filename = 'hello.txt',
            pathname = 'hello.txt',
        },
        {
            data = 'grault',
        },
    })

    -- test that throws an error if key is invalid
    local err = assert.throws(f.getraw, f, 123)
    assert.match(err, 'key must be string')

    -- test that throws an error if all is invalid
    err = assert.throws(f.getraw, f, 'key', {})
    assert.match(err, 'all must be boolean')
end

function testcase.set()
    local f = form.new()

    -- test that set key-value pair
    for _, v in ipairs({
        true,
        false,
        123,
        1.23,
        'bar',
        {
            header = {},
            data = 'bar',
        },
        {
            filename = 'hello.txt',
            pathname = 'hello.txt',
        },
        {
            filename = 'hello.txt',
            file = FILE,
        },
    }) do
        assert.is_true(f:set('foo', v))
        assert.equal(f:getraw('foo', true), {
            v,
        })
    end

    -- test that set method replaces old value with new value
    assert.is_true(f:set('foo', 'baz'))
    assert.equal(f:get('foo', true), {
        'baz',
    })

    -- test that set method removes a value
    assert.is_true(f:set('foo'))
    assert.is_nil(f:get('foo', true))

    -- test that it return false if key is not found
    assert.is_false(f:set('foo'))

    -- test that throws an error if key is invalid
    local err = assert.throws(f.set, f, ' hello ', 'world')
    assert.match(err, 'key must be string with no spaces')

    -- test that throws an error if val is invalid
    err = assert.throws(f.set, f, 'hello', function()
    end)
    assert.match(err, 'val must be boolean, string, number or table')

    -- test that throws an error if header field is invalid
    err = assert.throws(f.set, f, 'hello', {
        header = 123,
    })
    assert.match(err, 'header field must be table')

    -- test that throws an error if data field is invalid
    err = assert.throws(f.set, f, 'hello', {})
    assert.match(err, 'data field must be boolean, string or number')

    -- test that throws an error if filename field is invalid
    err = assert.throws(f.set, f, 'hello', {
        filename = 123,
    })
    assert.match(err, 'filename field must be string')

    -- test that throws an error if pathname field is invalid
    err = assert.throws(f.set, f, 'hello', {
        filename = 'hello',
    })
    assert.match(err, 'pathname field must be string')

    -- test that throws an error if file field is invalid
    err = assert.throws(f.set, f, 'hello', {
        filename = 'hello',
        file = 'foo',
    })
    assert.match(err, 'file field must be file*')
end

function testcase.add()
    local f = form.new()

    -- test that add value for key
    local exp = {}
    for _, v in ipairs({
        true,
        false,
        123,
        1.23,
        'bar',
        {
            header = {},
            data = 'bar',
        },
        {
            filename = 'hello.txt',
            pathname = 'hello.txt',
        },
        {
            filename = 'hello.txt',
            file = FILE,
        },
    }) do
        assert.is_true(f:add('foo', v))
        exp[#exp + 1] = v
        assert.equal(f:getraw('foo', true), exp)
    end

    -- test that throws an error if key is invalid
    local err = assert.throws(f.add, f, ' hello ', 'world')
    assert.match(err, 'key must be string with no spaces')

    -- test that throws an error if val is invalid
    err = assert.throws(f.set, f, 'hello', function()
    end)
    assert.match(err, 'val must be boolean, string, number or table')
end

function testcase.pairs()
    local f = form.new()
    f:add('foo', 'bar')
    f:add('foo', 'baz')
    f:add('qux', {
        data = 'quux',
    })

    -- test that iterate key-value pairs
    local data = {
        {
            foo = 'bar',
            qux = 'quux',
        },
        {
            foo = 'baz',
        },
    }
    for key, val, vidx in f:pairs() do
        assert.equal(data[vidx][key], val)
        data[vidx][key] = nil
        if not next(data[vidx]) then
            data[vidx] = nil
        end
    end
    assert.equal(data, {})

    data = {
        {
            foo = 'bar',
            qux = {
                data = 'quux',
            },
        },
        {
            foo = 'baz',
        },
    }
    for key, val, vidx in f:pairs(true) do
        assert.equal(data[vidx][key], val)
        data[vidx][key] = nil
        if not next(data[vidx]) then
            data[vidx] = nil
        end
    end
    assert.equal(data, {})

    -- test that throws an error if argument is invalid
    local err = assert.throws(f.pairs, f, {})
    assert.match(err, 'raw must be boolean')
end

function testcase.encode_urlencoded()
    local f = form.new()
    f:add('foo', 'bar')
    f:add('foo', {
        header = {
            hello = 'world',
        },
        data = 'baz',
    })
    f:add('foo', 'baa')
    f:add('qux', 'quux')

    -- test that encode to x-form-urlencoded format
    local str = ''
    local n = assert(f:encode({
        write = function(_, s)
            str = str .. s
            return #s
        end,
    }))
    assert.equal(n, #str)
    local kvpairs = {}
    for kv in string.gmatch(str, '([^&]+)') do
        kvpairs[#kvpairs + 1] = kv
    end
    table.sort(kvpairs)
    assert.equal(kvpairs, {
        'foo=baa',
        'foo=bar',
        'qux=quux',
    })
end

function testcase.decode_urlencoded()
    -- test that decode x-form-urlencoded format string to form
    local str = table.concat({
        'foo=baa',
        'foo=bar',
        'qux=quux',
    }, '&')
    local f, err = assert(form.decode({
        read = function(_, n)
            if #str > 0 then
                local s = string.sub(str, 1, n)
                str = string.sub(str, n + 1)
                return s
            end
        end,
    }))
    assert.is_nil(err)
    assert.equal(#str, 0)
    assert.equal(f.data, {
        foo = {
            'baa',
            'bar',
        },
        qux = {
            'quux',
        },
    })

    -- test that return error from reader
    f, err = form.decode({
        read = function()
            return nil, 'read error'
        end,
    })
    assert.is_nil(f)
    assert.match(err, 'read error')
end

function testcase.encode_multipart()
    local f = form.new()
    f:add('foo', 'bar')
    f:add('foo', {
        header = {
            hello = {
                'world',
            },
        },
        data = 'baz',
    })
    f:add('foo', 'baa')
    f:add('qux', 'quux')

    -- test that encode to x-form-urlencoded format
    local str = ''
    local n = assert(f:encode({
        write = function(_, s)
            str = str .. s
            return #s
        end,
        writefile = function(self, file, len, offset, part)
            file:seek('set', offset)
            local s, err = file:read(len)
            if part.is_tmpfile then
                file:close()
            end

            if err then
                return nil, string.format('failed to read file %q in %q: %s',
                                          part.filename, part.name, err)
            end
            return self:write(s)
        end,
    }, 'test_boundary'))
    assert.equal(n, #str)
    for _, part in ipairs({
        table.concat({
            '--test_boundary',
            'Content-Disposition: form-data; name="foo"',
            '',
            'bar',
            '',
        }, '\r\n'),
        table.concat({
            '--test_boundary',
            'hello: world',
            'Content-Disposition: form-data; name="foo"',
            '',
            'baz',
            '',
        }, '\r\n'),
        table.concat({
            '--test_boundary',
            'Content-Disposition: form-data; name="foo"',
            '',
            'baa',
            '',
        }, '\r\n'),
        table.concat({
            '--test_boundary',
            'Content-Disposition: form-data; name="qux"',
            '',
            'quux',
            '',
        }, '\r\n'),
        table.concat({
            '--test_boundary--',
        }, '\r\n'),
    }) do
        local head, tail = assert(string.find(str, part, nil, true))
        if head == 1 then
            str = string.sub(str, tail + 1)
        else
            str = string.sub(str, 1, head - 1) .. string.sub(str, tail + 1)
        end
    end
    assert.equal(#str, 0)
end

function testcase.decode_multipart()
    -- test that decode multipart/form-data format string to form
    local str = table.concat({
        table.concat({
            '--test_boundary',
            'Content-Disposition: form-data; name="foo"',
            '',
            'bar',
        }, '\r\n'),
        table.concat({
            '--test_boundary',
            'hello: world',
            'Content-Disposition: form-data; name="foo"',
            '',
            'baz',
        }, '\r\n'),
        table.concat({
            '--test_boundary',
            'Content-Disposition: form-data; name="foo"',
            '',
            'baa',
        }, '\r\n'),
        table.concat({
            '--test_boundary',
            'Content-Disposition: form-data; name="qux"',
            '',
            'quux',
        }, '\r\n'),
        '--test_boundary--',
    }, '\r\n')
    local f, err = assert(form.decode({
        read = function(_, n)
            if #str > 0 then
                local s = string.sub(str, 1, n)
                str = string.sub(str, n + 1)
                return s
            end
        end,
    }, nil, 'test_boundary'))
    assert.is_nil(err)
    assert.equal(#str, 0)
    assert.equal(f.data, {
        foo = {
            {
                header = {
                    ['content-disposition'] = {
                        'form-data; name="foo"',
                    },
                },
                name = 'foo',
                data = 'bar',
            },
            {
                header = {
                    hello = {
                        'world',
                    },
                    ['content-disposition'] = {
                        'form-data; name="foo"',
                    },
                },
                name = 'foo',
                data = 'baz',
            },
            {
                header = {
                    ['content-disposition'] = {
                        'form-data; name="foo"',
                    },
                },
                name = 'foo',
                data = 'baa',
            },
        },
        qux = {
            {
                header = {
                    ['content-disposition'] = {
                        'form-data; name="qux"',
                    },
                },
                name = 'qux',
                data = 'quux',
            },
        },
    })
end

