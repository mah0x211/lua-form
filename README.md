# lua-form

[![test](https://github.com/mah0x211/lua-form/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-form/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-form/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-form)

HTML form data processing module.

***

## Installation

```
luarocks install form
```

## f = form.new()

creating a form object.

**Returns**

- `f:form`: a form object.


## f, err, timeout = form.decode( chunk [, boundary [, maxfilesize [, filetmpl [, chunksize]]]] )

The legacy positional signature remains available unchanged. The new signature is:

```lua
f, err, timeout = form.decode(chunk [, opts])
```

Create a form object from `application/x-www-form-urlencoded` or
`multipart/form-data` input.

**Parameters**

- `chunk:string|table|userdata`: a string in `application/x-www-form-urlencoded` or `multipart/form-data` format.
    -  if the `chunk` parameter is not string, it must have the `chunk.read` method that reads the encoded string.
        ```
        s, err, timeout = chunk:read( chunksize )
        - s:string: a string in `application/x-www-form-urlencoded` or `multipart/form-data` format.
        - err:any: error value.
        - timeout:boolean: timeout flag for multipart input.
        - chunksize:integer: number of bytes read.
        ```
- `boundary:string|nil`: in the legacy signature, a valid multipart boundary.
  Omit it or pass `nil` for URL-encoded input.
- `maxfilesize:integer`: in the legacy signature, the maximum body bytes per
  multipart file.
- `filetmpl:string`: in the legacy signature, the temporary file path template.
- `chunksize:integer`: in the legacy signature, the maximum bytes requested
  per reader call.
- `opts:table`: when it is the only optional argument, supplies named options.
  Set `opts.boundary` for multipart input; omit it for URL-encoded input. The
  decoder leaves this table unchanged.

| Option | Legacy argument | Formats | Meaning |
| --- | --- | --- | --- |
| `boundary` | Second | Multipart | Multipart boundary. Omit it for URL-encoded input. |
| `chunksize` | Fifth | Both | Maximum bytes requested per reader call. A positive integer, default `4096`. |
| `maxsize` | | Both | Maximum total bytes received. Named options default to 128 KiB. Use `math.huge` for no total-size limit. |
| `deeply` | | URL-encoded | Split decoded keys at dots and create nested tables. Defaults to `false`. |
| `maxfilesize` | Third | Multipart | Maximum body bytes per file. Omit it for no per-file limit. |
| `filetmpl` | Fourth | Multipart | Temporary file path template. The decoder appends `_XXXXXX`. The default template is `/tmp/lua_form_multipart_XXXXXX`. |
| `maxparts` | | Multipart | Maximum number of text and file parts, including repeated fields. Defaults to `1000` with either calling convention. |
| `writer` | | Multipart | Optional writer for decoded file bodies. |

The legacy positional form has no total-size limit and remains shallow for
URL-encoded input. The multipart part-count limit of 1000 also applies to
legacy calls. Negative integer limits are treated as zero.

With `deeply=true`, URL-encoded keys produce nested tables in `f.data`, using
the structure returned by `form-urlencoded`. The flat `get`, `getall`,
`getraw`, `getrawall`, and `pairs` helpers are intended for shallow or
multipart data.

A multipart decode writer implements `n, err, timeout = writer:writefile(file, s)`.
It must return exactly `#s` on success and leave the destination file open.
The decoder handles file positioning and cleanup.

**Returns**

- `f:form|nil`: the decoded form, or `nil` on failure.
- `err:any`: the error from the decoder, when present.
- `timeout:boolean|nil`: `true` if a multipart reader or writer timed out.
  An error may accompany the timeout. A timeout alone returns `nil, nil, true`.

For decoded multipart parts, `form:getraw` and `form:getrawall` expose
Content-Disposition parameters in `part.params`. `part.header` retains
Content-Disposition and Content-Type.


## ok = form:set( key [, val] )

sets a `key`/`val` pair. if `val` is `nil`, the value associated with `key` will be removed.

**Parameters**

- `key:string`: a key string with no spaces.
- `val:boolean|string|number|table`: if a table value specified, it treat as `multipart/form-data` item. that fields must defined as the follows:
    - `header:table<string, any[]>|nil`: additional headers.
    - `data:boolean|string|number`: a data value.
    - `filename:string`: the filename to be used as the value of the `Content-Disposition` header. if this field specified, `data` field will be ignored.
    - `pathname:string`: the file indicated by this pathname will be used when encoding the form into a string.
    - `file:file*`: this file will be used when encoding the form into a string. if this field specified, `pathname` field will be ignored.

**Returns**

- `ok:boolean`: `true` on success.


## form:add( key val )

add a `val` for `key`.

**Parameters**

- `key:string`: a key string with no spaces.
- `val:boolean|string|number|table`: same of `f:set()`.


## val = form:get( key [, all] )

get the first value associated with the given key. if `all` is `true`, get all values as a list.

**NOTE:** if the value type is `table`, return the `data` field of the table.

**Parameters**

- `key:string`: a key string.
- `all:boolean`: get a list of values if `true`.

**Returns**

- `val:any`: the value associated with `key`.

**Usage**

```lua
local dump = require('dump')
local form = require('form')

local f = form.new()
f:add('foo', 'bar')
f:add('foo', 'baz')
f:add('foo', {
    data = 'qux',
})
print(dump(f:get('foo'))) -- "bar"
print(dump(f:get('foo', true))) -- { "bar", "baz", "qux" }
```

## data = form:getall( [all] )

get the first value for each form field (excluding `multipart/form-data` metadata). if `all` is `true`, get all values for each key as a list.

**Parameters**

- `all:boolean`: get a list of values if `true`.

**Returns**

- `data:table`: a table of all values in the form.


## val = form:getraw( key [, all] )

equivalent to `form:get` method but this method returns a raw value.


## data = form:getrawall( [all] )

equivalent to `form:getall` method but this method returns a raw value (including `multipart/form-data` metadata). if `all` is `true`, get all values for each key as a list.


## iter = form:pairs( [raw] )

get the iterator function.

**Parameters**

- `raw:boolean`: if `true` is specified, the iterator function returns a raw value.

**Returns**

- `iter:function`: the iterator function.
    ```
    key, val, vidx = iter()
    - key:string: key string.
    - val:boolean|string|number|table: value associated with key.
    - vidx:integer: an index number in the list of values.
    ```

**Usage**

```lua
local form = require('form')

local f = form.new()
f:add('foo', 'bar')
f:add('foo', 'baz')
f:add('qux', 'quux')
for key, val, vidx in f:pairs() do
    print(key, val, vidx)   -- foo bar  1
                            -- foo baz  2
                            -- qux quux 1
end
```


## res, err, timeout = form:encode( [boundary [, writer]] )

Encode the form in `application/x-www-form-urlencoded` or `multipart/form-data` format.

**Parameters**

- `boundary:string|nil`: a valid multipart boundary. Omit it or pass `nil`
  for URL-encoded output.
- `writer:table|userdata`: an optional destination for the encoded output.
  URL-encoded output calls `n, err = writer:write(s)` and adds up the
  byte counts the writer reports, including partial counts.
  Multipart output uses these methods.
    ```
    n, err, timeout = writer:write(s)
    n, err, timeout = writer:writefile(file, len, offset, part)
    ```
  On success, multipart writers must return exactly `#s` or `len`.
  The encoder stops on an incomplete write, an error, or a timeout.

Multipart file output starts at the current file position. The writer
receives that position as `offset`, the remaining length as `len`, and
the file part as `part`. The encoder closes files it opens from `pathname`.
The caller is responsible for closing supplied file handles.

**Returns**

- `res:string|integer|nil`: the encoded string without a writer, the number
  of bytes written with a writer, or `nil` on failure.
- `err:any`: the error from the encoder, when present.
- `timeout:boolean|nil`: `true` if a multipart writer timed out.
  An error may accompany the timeout. A timeout alone returns `nil, nil, true`.

