local json = {}

-- Escape special characters for JSON strings
local function escape_string(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\b", "\\b")
    s = string.gsub(s, "\f", "\\f")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

-- Check if table is an array (has consecutive integer keys starting from 1)
local function is_array(t)
    if type(t) ~= "table" then return false end
    local i = 1
    for k, v in pairs(t) do
        if k ~= i then return false end
        i = i + 1
    end
    return true
end

-- Convert Lua value to JSON string
function json.encode(value, indent)
    indent = indent or 0
    local t = type(value)
    
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return '"' .. escape_string(value) .. '"'
    elseif t == "table" then
        if is_array(value) then
            -- Handle arrays
            local result = "["
            for i, v in ipairs(value) do
                if i > 1 then result = result .. "," end
                result = result .. json.encode(v, indent + 1)
            end
            result = result .. "]"
            return result
        else
            -- Handle objects
            local result = "{"
            local first = true
            for k, v in pairs(value) do
                if type(k) == "string" or type(k) == "number" then
                    if not first then result = result .. "," end
                    first = false
                    local key = type(k) == "string" and k or tostring(k)
                    result = result .. '"' .. escape_string(key) .. '":' .. json.encode(v, indent + 1)
                end
            end
            result = result .. "}"
            return result
        end
    elseif t == "function" then
        return '"[function]"'  -- Functions can't be serialized to JSON
    else
        return '"[' .. t .. ']"'  -- Other types as string representation
    end
end

-- Pretty print JSON with indentation
function json.encode_pretty(value, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local t = type(value)
    
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return '"' .. escape_string(value) .. '"'
    elseif t == "table" then
        if is_array(value) then
            if #value == 0 then return "[]" end
            local result = "[\n"
            for i, v in ipairs(value) do
                if i > 1 then result = result .. ",\n" end
                result = result .. string.rep("  ", indent + 1) .. json.encode_pretty(v, indent + 1)
            end
            result = result .. "\n" .. spaces .. "]"
            return result
        else
            local keys = {}
            for k in pairs(value) do
                if type(k) == "string" or type(k) == "number" then
                    table.insert(keys, k)
                end
            end
            if #keys == 0 then return "{}" end
            
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            
            local result = "{\n"
            for i, k in ipairs(keys) do
                if i > 1 then result = result .. ",\n" end
                local key = type(k) == "string" and k or tostring(k)
                result = result .. string.rep("  ", indent + 1) .. '"' .. escape_string(key) .. '": ' .. json.encode_pretty(value[k], indent + 1)
            end
            result = result .. "\n" .. spaces .. "}"
            return result
        end
    elseif t == "function" then
        return '"[function]"'
    else
        return '"[' .. t .. ']"'
    end
end

-- Simple JSON decoder
local function skip_whitespace(str, pos)
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c ~= ' ' and c ~= '\t' and c ~= '\n' and c ~= '\r' then
            break
        end
        pos = pos + 1
    end
    return pos
end

local function decode_string(str, pos)
    if str:sub(pos, pos) ~= '"' then
        error("Expected '\"' at position " .. pos)
    end
    pos = pos + 1
    local result = ""
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return result, pos + 1
        elseif c == '\\' then
            pos = pos + 1
            local escape = str:sub(pos, pos)
            if escape == 'n' then result = result .. '\n'
            elseif escape == 't' then result = result .. '\t'
            elseif escape == 'r' then result = result .. '\r'
            elseif escape == 'b' then result = result .. '\b'
            elseif escape == 'f' then result = result .. '\f'
            elseif escape == '"' then result = result .. '"'
            elseif escape == '\\' then result = result .. '\\'
            else result = result .. escape end
        else
            result = result .. c
        end
        pos = pos + 1
    end
    error("Unterminated string")
end

local function decode_number(str, pos)
    local start_pos = pos
    if str:sub(pos, pos) == '-' then pos = pos + 1 end
    while pos <= #str and str:sub(pos, pos):match('%d') do
        pos = pos + 1
    end
    if pos <= #str and str:sub(pos, pos) == '.' then
        pos = pos + 1
        while pos <= #str and str:sub(pos, pos):match('%d') do
            pos = pos + 1
        end
    end
    local num_str = str:sub(start_pos, pos - 1)
    return tonumber(num_str), pos
end

local decode_value  -- Forward declaration

local function decode_array(str, pos)
    if str:sub(pos, pos) ~= '[' then
        error("Expected '[' at position " .. pos)
    end
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    
    local result = {}
    if str:sub(pos, pos) == ']' then
        return result, pos + 1
    end
    
    while true do
        local value
        value, pos = decode_value(str, pos)
        table.insert(result, value)
        
        pos = skip_whitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == ']' then
            return result, pos + 1
        elseif c == ',' then
            pos = pos + 1
            pos = skip_whitespace(str, pos)
        else
            error("Expected ',' or ']' at position " .. pos)
        end
    end
end

local function decode_object(str, pos)
    if str:sub(pos, pos) ~= '{' then
        error("Expected '{' at position " .. pos)
    end
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    
    local result = {}
    if str:sub(pos, pos) == '}' then
        return result, pos + 1
    end
    
    while true do
        local key
        key, pos = decode_string(str, pos)
        pos = skip_whitespace(str, pos)
        
        if str:sub(pos, pos) ~= ':' then
            error("Expected ':' at position " .. pos)
        end
        pos = pos + 1
        pos = skip_whitespace(str, pos)
        
        local value
        value, pos = decode_value(str, pos)
        result[key] = value
        
        pos = skip_whitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == '}' then
            return result, pos + 1
        elseif c == ',' then
            pos = pos + 1
            pos = skip_whitespace(str, pos)
        else
            error("Expected ',' or '}' at position " .. pos)
        end
    end
end

function decode_value(str, pos)
    pos = skip_whitespace(str, pos)
    local c = str:sub(pos, pos)
    
    if c == '"' then
        return decode_string(str, pos)
    elseif c == '[' then
        return decode_array(str, pos)
    elseif c == '{' then
        return decode_object(str, pos)
    elseif c == 't' then
        if str:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        end
    elseif c == 'f' then
        if str:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        end
    elseif c == 'n' then
        if str:sub(pos, pos + 3) == "null" then
            return nil, pos + 4
        end
    elseif c:match('[%d%-]') then
        return decode_number(str, pos)
    end
    error("Unexpected character '" .. c .. "' at position " .. pos)
end

function json.decode(str)
    if not str or str == "" then
        return nil
    end
    local value, pos = decode_value(str, 1)
    pos = skip_whitespace(str, pos)
    if pos <= #str then
        error("Extra characters after JSON at position " .. pos)
    end
    return value
end

return json
