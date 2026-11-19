require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local errno = require('errno')
local errors = require('error')
local form = require('form')
local multipart = require('form.multipart')

local BOUNDARY = 'test_boundary'

function testcase.urlencoded_decode_options()
    local text = 'field.name=value'
    local offset = 1
    local options = {
        chunksize = 2,
        maxsize = #text,
        deeply = true,
        maxparts = 0,
        writer = false,
    }
    local f = assert(form.decode({
        read = function(_, n)
            assert(n > 0 and n <= 2)
            local s = text:sub(offset, offset + n - 1)
            offset = offset + #s
            return s
        end,
    }, options))
    assert.equal(f.data, {
        field = {
            name = {
                'value',
            },
        },
    })
    assert.equal(options, {
        chunksize = 2,
        maxsize = #text,
        deeply = true,
        maxparts = 0,
        writer = false,
    })

    local decoded, limit_err = form.decode(text, {
        maxsize = #text - 1,
    })
    assert.is_nil(decoded)
    assert.match(tostring(limit_err), 'exceeds maxsize')

    local err = {}
    local result, cause = form.decode({
        read = function(_, n)
            assert.equal(n, 7)
            return nil, err
        end,
    }, nil, nil, nil, 7)
    assert.is_nil(result)
    assert(rawequal(cause, err))
end

function testcase.decode_default_and_legacy_size_limits()
    local value = string.rep('a', 128 * 1024)
    local urlencoded = 'value=' .. value
    local f = form.new()
    f:add('value', value)
    local encoded = assert(f:encode(BOUNDARY))

    local decoded, err = form.decode(urlencoded, {})
    assert.is_nil(decoded)
    assert.match(tostring(err), 'exceeds maxsize')
    assert.equal(assert(form.decode(urlencoded)):get('value'), value)

    decoded, err = form.decode(encoded, {
        boundary = BOUNDARY,
    })
    assert.is_nil(decoded)
    assert(errors.is(err, errno.EFBIG))
    assert.equal(assert(form.decode(encoded, BOUNDARY)):get('value'), value)
    assert.equal(assert(form.decode(encoded, {
        boundary = BOUNDARY,
        maxsize = math.huge,
    })):get('value'), value)
end

function testcase.multipart_decode_file_options()
    local encoded = table.concat({
        '--' .. BOUNDARY,
        'Content-Disposition: form-data; name="text"',
        '',
        'value',
        '--' .. BOUNDARY,
        'Content-Disposition: form-data; name="file"; filename="a.txt"',
        '',
        'blob',
        '--' .. BOUNDARY .. '--',
    }, '\r\n')
    local offset = 1
    local written = 0
    local writer = {
        writefile = function(_, file, bytes)
            assert(file:write(bytes))
            written = written + #bytes
            return #bytes
        end,
    }
    local options = {
        boundary = BOUNDARY,
        chunksize = 7,
        maxsize = #encoded,
        maxfilesize = 4,
        maxparts = 2,
        filetmpl = 'form-test-file',
        writer = writer,
    }
    local f = assert(form.decode({
        read = function(_, n)
            assert(n > 0 and n <= 7)
            local s = encoded:sub(offset, offset + n - 1)
            offset = offset + #s
            return s
        end,
    }, options))
    local file = f:getraw('file')
    local contents = file.file:read('*a')
    file.file:close()
    assert(os.remove(file.pathname))
    assert.equal(contents, 'blob')
    assert.match(file.pathname, '^form%-test%-file_', false)
    assert.equal(file.params.filename, 'a.txt')
    assert.equal(f:get('text'), 'value')
    assert.equal(written, 4)
    assert.equal(options, {
        boundary = BOUNDARY,
        chunksize = 7,
        maxsize = #encoded,
        maxfilesize = 4,
        maxparts = 2,
        filetmpl = 'form-test-file',
        writer = writer,
    })

    local decoded, err = form.decode(encoded, {
        boundary = BOUNDARY,
        maxsize = #encoded - 1,
        filetmpl = 'form-test-file',
    })
    assert.is_nil(decoded)
    assert(errors.is(err, errno.EFBIG))

    decoded, err = form.decode(encoded, BOUNDARY, 3, 'form-test-file')
    assert.is_nil(decoded)
    assert(errors.is(err, errno.EFBIG))

    decoded, err = form.decode(encoded, {
        boundary = BOUNDARY,
        maxparts = 1,
    })
    assert.is_nil(decoded)
    assert(errors.is(err, errno.E2BIG))

    err = assert.throws(form.decode, encoded, BOUNDARY, {}, nil)
    assert.match(err, 'maxfilesize must be integer')

    local timeout
    decoded, err, timeout = form.decode(encoded, {
        boundary = BOUNDARY,
        filetmpl = 'form-test-file',
        writer = {
            writefile = function()
                return nil, nil, true
            end,
        },
    })
    assert.is_nil(decoded)
    assert.is_nil(err)
    assert.is_true(timeout)
end

function testcase.multipart_timeout_results()
    local cause = errors.new('callback failed')
    for _, result in ipairs({
        { timeout = true },
        { err = cause, timeout = true },
        { err = cause },
    }) do
        local f, err, timeout = form.decode({
            read = function()
                return nil, result.err, result.timeout
            end,
        }, {
            boundary = BOUNDARY,
        })
        assert.is_nil(f)
        assert.equal(timeout, result.timeout)
        if result.err then
            assert.equal(errors.typeof(err), multipart.EDECODE)
            assert(rawequal(errors.unwrap(err), result.err))
        else
            assert.is_nil(err)
        end

        local n
        n, err, timeout = form.new():encode(BOUNDARY, {
            write = function()
                return nil, result.err, result.timeout
            end,
            writefile = function()
                error('unexpected file write')
            end,
        })
        assert.is_nil(n)
        assert.equal(timeout, result.timeout)
        if result.err then
            assert.equal(errors.typeof(err), multipart.EENCODE)
            assert(rawequal(errors.unwrap(err), result.err))
        else
            assert.is_nil(err)
        end
    end
end

function testcase.encode_writer_counts()
    local f = form.new()
    f:add('flag', 12)
    f:add('flag', true)
    assert.equal(assert(f:encode()), 'flag=12&flag=true')
    local n = assert(f:encode(nil, {
        write = function()
            return 1
        end,
    }))
    assert.equal(n, 2)

    local written, err = f:encode(BOUNDARY, {
        write = function(_, s)
            return #s - 1
        end,
        writefile = function()
            error('unexpected file write')
        end,
    })
    assert.is_nil(written)
    assert(errors.is(err, errno.EIO))
end

function testcase.multipart_roundtrip()
    local f = form.new()
    f:add('message', {
        data = 'hello',
        header = {
            ['Content-Type'] = {
                'text/plain',
            },
        },
    })
    local decoded = assert(form.decode(assert(f:encode(BOUNDARY)), BOUNDARY))
    local roundtrip = assert(form.decode(assert(decoded:encode(BOUNDARY)), BOUNDARY))
    assert.equal(roundtrip:get('message'), 'hello')
    assert.equal(roundtrip:getraw('message'), {
        data = 'hello',
        name = 'message',
        params = {
            name = 'message',
        },
        header = {
            ['content-disposition'] = {
                'form-data; name="message"',
            },
            ['content-type'] = {
                'text/plain',
            },
        },
    })
end

function testcase.decode_rejects_non_string_boundary()
    local err = assert.throws(form.decode, '', false)
    assert.match(err, 'boundary must be string')

    err = assert.throws(form.decode, '', {
        boundary = false,
    })
    assert.match(err, 'boundary must be string')
end
