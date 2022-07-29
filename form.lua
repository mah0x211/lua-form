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
local isa = require('isa')
local is_string = isa.string
local is_table = isa.table
local is_file = isa.file
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

--- get
--- @param key string
--- @param all boolean
--- @return string|number|boolean|table|nil val
function Form:get(key, all)
    if not is_string(key) then
        error('key must be string', 2)
    end

    local vals = self.data[key]
    if vals then
        return all == true and vals or vals[1]
    end
end

local VALID_DATATYPE = {
    ['string'] = true,
    ['number'] = true,
    ['boolean'] = true,
}

--- verify_multipart_data
--- @param v any
--- @return table
local function verify_multipart_data(v)
    if not is_table(v) then
        error('val must be boolean, string, number or table', 3)
    elseif v.header ~= nil and not is_table(v.header) then
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
    elseif not is_string(v.filename) then
        -- invalid filename field
        error('filename field must be string', 3)
    elseif v.file == nil then
        if not is_string(v.pathname) then
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
--- @param val string|boolean|number|table|nil
--- @return boolean ok
function Form:set(key, val)
    if not is_string(key) or find(key, '%s') then
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
    if not is_string(key) or find(key, '%s') then
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
--- @return function next
function Form:pairs()
    local data = self.data
    local key, values = next(data)
    local vidx = 0

    return function()
        repeat
            if values then
                vidx = vidx + 1
                if values[vidx] then
                    return key, values[vidx], vidx
                end
                vidx = 0
            end

            key, values = next(data, key)
        until key == nil
    end
end

--- encode
--- @param writer table|userdata
--- @param boundary string|nil
--- @param chunksize integer|nil
--- @return integer|nil nbyte
--- @return any err
function Form:encode(writer, boundary, chunksize)
    if boundary == nil then
        return encode_urlencoded(writer, self.data)
    end
    return encode_multipart(writer, self.data, boundary, chunksize)
end

Form = require('metamodule').new(Form)

--- decode
---@param reader table|userdata
---@param chunksize integer|nil
---@param boundary string|nil
---@param maxsize integer|nil
---@param filetmpl string|nil
---@return form|nil form
---@return any err
local function decode(reader, chunksize, boundary, maxsize, filetmpl)
    local data, err
    if boundary == nil then
        data, err = decode_urlencoded(reader, chunksize)
    elseif is_string(boundary) then
        data, err = decode_multipart(reader, boundary, filetmpl, maxsize,
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
}

