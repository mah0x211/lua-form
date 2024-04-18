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

--- @class form.writer
--- @field write fun(self, s:string):(n:integer, err:any)
--- @field writefile fun(self, f:file*, len:integer, offset:integer, part:table):(n:integer, err:any)

--- encode
--- @param boundary string?
--- @param writer? form.writer
--- @return integer|string? res
--- @return any err
function Form:encode(boundary, writer)
    if boundary == nil then
        return encode_urlencoded(self.data, nil, writer)
    end
    return encode_multipart(self.data, boundary, writer)
end

Form = require('metamodule').new(Form)

--- @class form.reader
--- @field read fun(self, chunksize:integer):string

--- decode
--- @param chunk string|form.reader
--- @param boundary string?
--- @param maxsize integer?
--- @param filetmpl string?
--- @param chunksize integer?
--- @return form? form
--- @return any err
local function decode(chunk, boundary, maxsize, filetmpl, chunksize)
    local data, err
    if boundary == nil then
        data, err = decode_urlencoded(chunk, nil, chunksize)
    elseif type(boundary) == 'string' then
        data, err = decode_multipart(chunk, boundary, filetmpl, maxsize,
                                     chunksize)
    end
    if err then
        return nil, err
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

