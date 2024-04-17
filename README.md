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


## f, err = form.decode( chunk [, chunksize [, boundary [, maxsize [, filetmpl]]]] )

create a form object from a string in `application/x-form-urlencoded` or `multipart/form-data` encoded format.

**Parameters**

- `chunk:string|table|userdata`: a string in `application/x-form-urlencoded` or `multipart/form-data` format.
    -  if the `chunk` parameter is not string, it must have the `chunk.read` method that reads the encoded string.
        ```
        s, err = chunk:read( chunksize )
        - s:string: a string in `application/x-form-urlencoded` or `multipart/form-data` format.
        - err:any: error value.
        - chunksize:integer: number of bytes read.
        ```
- `chunksize:integer`: number of byte to read from the `reader.read` method. this value must be greater than `0`. (default: `4096`)
- `boundary:string`: if specify a boundary string, treat the loaded string as `multipart/form-data`.
- `filetmpl:string`: template for the filename to be created. the filename will be appended with `_XXXXXX` at the end. the `_XXXXXXXX` will be a random string. (default: `/tmp/lua_form_multipart_XXXXXX`)
- `maxsize:integer`: limit the maximum size per file.


**Returns**

- `f:form`: a form object.
- `err:any`: error value


## ok = f:set( key [, val] )

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


## f:add( key val )

add a `val` for `key`.

**Parameters**

- `key:string`: a key string with no spaces.
- `val:boolean|string|number|table`: same of `f:set()`.


## val = f:get( key [, all] )

get the first `val` in the list of valeues associated with `key`. also, if `all` argument is `true`, get a list of values.

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


## val = f:getraw( key [, all] )

equivalent to `f:get` method but this method returns a raw value.


## iter = f:pairs( [raw] )

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


## res, err = f:encode( [writer [, boundary]] )

encode the form into a string in `application/x-form-urlencoded` or `multipart/form-data` format.

**Parameters**

- `writer:table|userdata`: call the `writer:write` method to output a string.
    ```
    n, err = writer:write( s )
    - n:integer: number of bytes written.
    - err:any: error value.
    - s:string: output string.
    ```
    if `boundary` argument specified, call the `writer:writefile` method to output a file data.
    ```
    n, err = writer:writefile( file, len, offset, part )
    - n:integer: number of bytes written.
    - err:any: error value.
    - len:integer: file size.
    - offset:integer: file offset at which to begin the writeout.
    - part:table: a file data that contains the `filename` and `file` fields. if `part.is_tmpfile` is `true`, `file` must be closed by this method.
    ```
- `boundary:string`: if specify a boundary string, this form will be encoded in `multipart/form-data`.


**Returns**

- `res:string|integer`: a string in `application/x-form-urlencoded` or `multipart/form-data` format, or number of bytes written.
    - if the `writer` parameter is not specified, it returns a string in `application/x-form-urlencoded` or `multipart/form-data` format.
    - otherwise, it returns the number of bytes written to the `writer:write` and `writer:writefile` methods.
- `err:any`: error value.

