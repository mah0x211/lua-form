--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local find = string.find
local type = type
local is_file = require('lauxhlib.is').file
local urlencoded = require('form.urlencoded')
local encode_urlencoded = urlencoded.encode
local decode_urlencoded = urlencoded.decode
local multipart = require('form.multipart')
local encode_multipart = multipart.encode
local decode_multipart = multipart.decode

--- @class form
--- @field data table
local Form = {}

--- init
--- @return form
function Form:init()
    self.data = {}
    return self
end

local VALID_DATATYPE = {
    ['string'] = true,
    ['number'] = true,
    ['boolean'] = true,
}

--- get
--- @param key string
--- @param all boolean
--- @return string|number|boolean|table? val
function Form:get(key, all)
    if type(key) ~= 'string' then
        error('key must be string', 2)
    elseif all ~= nil and type(all) ~= 'boolean' then
        error('all must be boolean', 2)
    end

    local vals = self.data[key]
    if vals then
        if all then
            local list = {}
            for i = 1, #vals do
                local val = vals[i]
                if VALID_DATATYPE[type(val)] then
                    list[#list + 1] = val
                else
                    list[#list + 1] = val.data
                end
            end
            return list
        end

        local val = vals[1]
        if VALID_DATATYPE[type(val)] then
            return val
        end
        return val.data
    end
end

--- getall
--- @param all boolean?
--- @return table data
function Form:getall(all)
    if all ~= nil and type(all) ~= 'boolean' then
        error('all must be boolean', 2)
    end

    local data = {}
    for key, vals in pairs(self.data) do
        if not all then
            local val = vals[1]
            data[key] = VALID_DATATYPE[type(val)] and val or val.data
        else
            local list = {}
            for i = 1, #vals do
                local val = vals[i]
                if VALID_DATATYPE[type(val)] then
                    list[#list + 1] = val
                else
                    list[#list + 1] = val.data
                end
            end
            data[key] = #list > 0 and list or nil
        end
    end

    return data
end

--- getraw
--- @param key string
--- @param all boolean
--- @return string|number|boolean|table? val
function Form:getraw(key, all)
    if type(key) ~= 'string' then
        error('key must be string', 2)
    elseif all ~= nil and type(all) ~= 'boolean' then
        error('all must be boolean', 2)
    end

    local vals = self.data[key]
    if vals then
        return all and vals or vals[1]
    end
end

--- getrawall
--- @param all boolean?
--- @return table data
function Form:getrawall(all)
    if all ~= nil and type(all) ~= 'boolean' then
        error('all must be boolean', 2)
    end

    local data = {}
    for key, vals in pairs(self.data) do
        if not all then
            data[key] = vals[1]
        else
            data[key] = vals
        end
    end

    return data
end

--- verify_multipart_data
--- @param v any
--- @return table
local function verify_multipart_data(v)
    if type(v) ~= 'table' then
        error('val must be boolean, string, number or table', 3)
    elseif v.header ~= nil and type(v.header) ~= 'table' then
        -- invalid header field
        error('header field must be table', 3)
    elseif v.filename == nil then
        if not VALID_DATATYPE[type(v.data)] then
            error('data field must be boolean, string or number', 3)
        end
        return {
            header = v.header,
            data = v.data,
        }
    elseif type(v.filename) ~= 'string' then
        -- invalid filename field
        error('filename field must be string', 3)
    elseif v.file == nil then
        if type(v.pathname) ~= 'string' then
            error('pathname field must be string', 3)
        end
        return {
            header = v.header,
            filename = v.filename,
            pathname = v.pathname,
        }
    elseif not is_file(v.file) then
        -- invalid file field
        error('file field must be file*', 3)
    end

    return {
        header = v.header,
        filename = v.filename,
        file = v.file,
    }
end

--- set
--- @param key string
--- @param val string|boolean|number|table?
--- @return boolean ok
function Form:set(key, val)
    if type(key) ~= 'string' or find(key, '%s') then
        error('key must be string with no spaces', 2)
    elseif val == nil then
        -- remove the value for key
        local v = self.data[key]
        if v then
            self.data[key] = nil
            return true
        end
        return false
    elseif VALID_DATATYPE[type(val)] then
        self.data[key] = {
            val,
        }
        return true
    end

    self.data[key] = {
        verify_multipart_data(val),
    }
    return true
end

--- add
--- @param key string
--- @param val string|boolean|number|table
--- @return boolean ok
function Form:add(key, val)
    if type(key) ~= 'string' or find(key, '%s') then
        error('key must be string with no spaces', 2)
    elseif not VALID_DATATYPE[type(val)] then
        val = verify_multipart_data(val)
    end

    -- append value
    local vals = self.data[key]
    if vals then
        vals[#vals + 1] = val
    else
        self.data[key] = {
            val,
        }
    end

    return true
end

--- pairs
--- @param raw boolean
--- @return function next
function Form:pairs(raw)
    if raw ~= nil and type(raw) ~= 'boolean' then
        error('raw must be boolean', 2)
    end

    local data = self.data
    local key, values = next(data)
    local vidx = 0

    return function()
        repeat
            if values then
                repeat
                    vidx = vidx + 1
                    local val = values[vidx]
                    if not val then
                        vidx = 0
                    elseif raw or VALID_DATATYPE[type(val)] then
                        return key, val, vidx
                    elseif val.data then
                        return key, val.data, vidx
                    end
                until vidx == 0
            end

            key, values = next(data, key)
        until key == nil
    end
end

--- @class form.urlencoded.writer
--- @field write fun(self, s:string):(n:integer?, err:any)

--- @class form.writer
--- @field write fun(self, s:string):(n:integer?, err:any, timeout:boolean?)
--- @field writefile fun(self, f:file*, len:integer, offset:integer, part:table):(n:integer?, err:any, timeout:boolean?)

--- encode
--- @param boundary string?
--- @param writer? form.urlencoded.writer|form.writer
--- @return integer|string? res
--- @return any err
--- @return boolean? timeout Multipart only.
function Form:encode(boundary, writer)
    if boundary == nil then
        return encode_urlencoded(self.data, nil, writer)
    end
    return encode_multipart(self.data, boundary, writer)
end

Form = require('metamodule').new(Form)

--- @class form.reader
--- @field read fun(self, chunksize:integer):(s:string?, err:any, timeout:boolean?)

--- @class form.decode_writer
--- @field writefile fun(self, f:file*, s:string):(n:integer?, err:any, timeout:boolean?)

--- @class form.decode_options
--- @field boundary? string Multipart boundary. Omit for URL-encoded input.
--- @field chunksize? integer
--- @field deeply? boolean URL-encoded only.
--- @field maxsize? number
--- @field filetmpl? string Multipart only.
--- @field maxfilesize? integer Multipart only.
--- @field maxparts? integer Multipart only.
--- @field writer? form.decode_writer Multipart only.

--- decode with options
--- @param chunk string|form.reader
--- @param opts form.decode_options
--- @return form? form
--- @return any err
--- @return boolean? timeout Multipart only.
local function decode_with_opts(chunk, opts)
    local boundary = opts.boundary
    local data, err, timeout
    if boundary == nil then
        data, err = decode_urlencoded(chunk, {
            chunksize = opts.chunksize,
            deeply = opts.deeply,
            maxsize = opts.maxsize,
        })
    else
        data, err, timeout = decode_multipart(chunk, boundary, {
            chunksize = opts.chunksize,
            filetmpl = opts.filetmpl,
            maxfilesize = opts.maxfilesize,
            maxparts = opts.maxparts,
            maxsize = opts.maxsize,
            writer = opts.writer,
        })
    end

    if err or timeout then
        return nil, err, timeout
    end

    local form = Form()
    form.data = data
    return form
end

--- decode
--- @param chunk string|form.reader
--- @param ... form.decode_options|string|integer|nil Options, or legacy boundary, maxfilesize, filetmpl, chunksize.
--- @return form? form
--- @return any err
--- @return boolean? timeout Multipart only.
local function decode(chunk, ...)
    local boundary, maxfilesize, filetmpl, chunksize = ...
    if select('#', ...) == 1 and type(boundary) == 'table' then
        return decode_with_opts(chunk, boundary)
    end

    local data, err, timeout
    if boundary == nil then
        data, err = decode_urlencoded(chunk, nil, chunksize)
    else
        data, err, timeout = decode_multipart(chunk, boundary, filetmpl,
                                              maxfilesize, chunksize)
    end

    if err or timeout then
        return nil, err, timeout
    end

    local form = Form()
    form.data = data
    return form
end

return {
    new = Form,
    decode = decode,
    is_valid_boundary = multipart.is_valid_boundary,
}

