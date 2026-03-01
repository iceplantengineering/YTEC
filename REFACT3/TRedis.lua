--redis操作元类
TRedis = {}

local xt = xshare.new('muthread share table')

-- 连接池管理
local redis_connection = nil
local connection_params = {
    host = '127.0.0.1',
    port = 6379,
}

function TRedis:getRedis()
    local redis = require 'redis'
    
    -- 使用连接池，避免频繁创建连接
    if not redis_connection then
        redis_connection = redis.connect(connection_params)
        redis_connection:select(14)
    end
    
    return redis_connection, redis
end

-- 优化后的hmget1方法，增加错误处理
function TRedis:hmget1(key, fk)
    if not key or #key == 0 or not fk then
        return nil
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return nil
    end
    
    local success, result = pcall(function()
        local tb = {fk}
        local val = client:hmget(key, tb)
        if val and val[1] then
            local decode_success, decoded_val = pcall(function()
                return cjson8.decode(val[1])
            end)
            if decode_success then
                return decoded_val
            else
                print("JSON解码失败: " .. tostring(decoded_val))
                return nil
            end
        end
        return nil
    end)
    
    if not success then
        print("hmget1执行失败: " .. tostring(result))
        return nil
    end
    
    return result
end
--client redis客户端连接对象
-- redis 工具库对象
-- 优化后的setHash方法
function TRedis:setHash(key, ...)
    if not key or #key == 0 then
        return false
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return false
    end
    
    local args = {...}
    if #args == 0 then
        return false
    end
    
    local success, result = pcall(function()
        local command = {"hmset", key}
        
        for i = 1, #args, 2 do
            if args[i + 1] ~= nil then  -- 确保有值
                table.insert(command, args[i])
                table.insert(command, args[i + 1])
            end
        end
        
        if #command > 2 then  -- 确保有数据要设置
            local unpack = _G.unpack or table.unpack
            return redis_lib.call(unpack(command))
        end
        return false
    end)
    
    if not success then
        print("setHash执行失败: " .. tostring(result))
        return false
    end
    
    return result
end

-- 优化后的encode方法
function TRedis:encode(tb)
    if not tb or type(tb) ~= "table" then
        return ""
    end
    
    local vt = {}
    for k, v in pairs(tb) do
        local vtype = type(v)
        if vtype == "string" or vtype == "number" or vtype == "boolean" then
            vt[k] = v
        elseif vtype == "table" then
            -- 递归处理嵌套table
            local success, encoded = pcall(function()
                return cjson8.encode(v)
            end)
            if success then
                vt[k] = encoded
            end
        end
    end
    
    local dt = os.time()
    local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
    vt.updateTime = st
    
    local success, result = pcall(function()
        return cjson8.encode(vt)
    end)
    
    if success then
        return result
    else
        print("JSON编码失败: " .. tostring(result))
        return ""
    end
end

-- 优化后的hmset1方法
function TRedis:hmset1(key, val, fk)
    if not key or #key == 0 or not val or not fk then
        return false
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return false
    end
    
    local success, result = pcall(function()
        local dt = os.time()
        local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
        val.updateTime = st
        
        local ss = self:encode(val)
        if not ss or #ss == 0 then
            return false
        end
        
        local tb = {[fk] = ss}
        return client:hmset(key, tb)
    end)
    
    if not success then
        print("hmset1执行失败: " .. tostring(result))
        return false
    end
    
    return result
end

-- 优化后的clearOldHashFields方法
function TRedis:clearOldHashFields(key)
    if not key or #key == 0 then
        return 0
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return 0
    end
    
    local deleted_count = 0
    local success, result = pcall(function()
        local fields = client:hkeys(key)
        local now = os.time()
        
        for _, field in ipairs(fields) do
            local val = client:hget(key, field)
            if val and #val > 0 then
                local ok, data = pcall(function() 
                    return cjson8.decode(val) 
                end)
                
                if ok and data and data.updateTime then
                    local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
                    local y, m, d, h, min, s = string.match(data.updateTime, pattern)
                    if y then
                        local success, t = pcall(function()
                            return os.time{
                                year = tonumber(y), 
                                month = tonumber(m), 
                                day = tonumber(d), 
                                hour = tonumber(h), 
                                min = tonumber(min), 
                                sec = tonumber(s)
                            }
                        end)
                        
                        if success and now - t > 7 * 24 * 3600 then
                            client:hdel(key, field)
                            deleted_count = deleted_count + 1
                        end
                    end
                end
            end
        end
    end)
    
    if not success then
        print("clearOldHashFields执行失败: " .. tostring(result))
        return 0
    end
    
    return deleted_count
end

-- 优化后的hmset2方法
function TRedis:hmset2(key, val)
    if not key or #key == 0 or not val then
        return false
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return false
    end
    
    local success, result = pcall(function()
        return client:hmset(key, val)
    end)
    
    if not success then
        print("hmset2执行失败: " .. tostring(result))
        return false
    end
    
    return result
end

-- 优化后的hmsets方法
function TRedis:hmsets(key, tlist, kfname)
    if not key or #key == 0 or not tlist or not kfname or #kfname == 0 then
        return false
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return false
    end
    
    local success, result = pcall(function()
        local tbs = {}
        
        for k, v in pairs(tlist) do
            if type(v) == "table" then
                local kv = v[kfname] or "00"
                local ss = self:encode(v)
                if ss and #ss > 0 then
                    tbs[kv] = ss
                end
            end
        end
        
        if next(tbs) then  -- 确保有数据要设置
            return client:hmset(key, tbs)
        end
        return false
    end)
    
    if not success then
        print("hmsets执行失败: " .. tostring(result))
        return false
    end
    
    return result
end

-- 优化后的createThreadInfo方法
function TRedis:createThreadInfo(sid, info)
    if not sid or not info then
        return false
    end
    
    local success = self:hmset1("threadlist", info, sid)
    if success then
        -- 热更新lua脚本或动态执行lua函数
        local key = 'lua:' .. sid
        self:loadLua(key)
    end
    
    return success
end

-- 优化后的createRedisInfo方法
function TRedis:createRedisInfo(skey, sid, info)
    if not xt or not xt.redisInfo then 
        return false
    end
    
    if not skey or not sid or not info then
        return false
    end
    
    local success, ss = pcall(function()
        local encoded_info = self:encode(info) or ""
        local tb = {key = skey, id = sid, msg = encoded_info}
        return self:encode(tb) or ""
    end)
    
    if not success then
        print("createRedisInfo编码失败: " .. tostring(ss))
        return false
    end
    
    if ss and #ss > 0 then
        TXShare:setInfo(xt.redisInfo, ss)
        return true
    end
    
    return false
end

-- 优化后的loadLua方法
function TRedis:loadLua(key)
    if not key or #key == 0 then
        return false
    end
    
    local lua_content = self:getString(key) or "0"
    if #lua_content > 1 then
        self:setString(key, "0")
        log(lua_content)
        
        local success, err = pcall(function()
            local lua_func, compile_err = load(lua_content)
            if lua_func then
                return lua_func()
            else
                return nil, compile_err
            end
        end)
        
        log("Lua执行结果:", success, err)
        return success
    end
    
    return false
end

-- 优化后的getString方法
function TRedis:getString(key)
    if not key or #key == 0 then
        return nil
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return nil
    end
    
    local success, result = pcall(function()
        return client:get(key)
    end)
    
    if not success then
        print("getString执行失败: " .. tostring(result))
        return nil
    end
    
    return result
end

-- 优化后的setString方法
function TRedis:setString(key, val)
    if not key or #key == 0 then
        return false
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return false
    end
    
    local success, result = pcall(function()
        return client:set(key, val)
    end)
    
    if not success then
        print("setString执行失败: " .. tostring(result))
        return false
    end
    
    return result
end

-- 优化后的delString方法
function TRedis:delString(key)
    if not key or #key == 0 then
        return false
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return false
    end
    
    local success, result = pcall(function()
        return client:del(key)
    end)
    
    if not success then
        print("delString执行失败: " .. tostring(result))
        return false
    end
    
    return result
end

-- 新增：获取list指定索引元素的方法
function TRedis:lindex(key, index)
    if not key or #key == 0 then
        return nil
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return nil
    end
    
    local success, result = pcall(function()
        return client:lindex(key, index)
    end)
    
    if not success then
        print("lindex执行失败: " .. tostring(result))
        return nil
    end
    
    return result
end

-- 优化后的lrange方法（修复bug）
function TRedis:lrange(key, start, ends)
    if not key or #key == 0 then
        return {}
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return {}
    end
    
    local success, result = pcall(function()
        return client:lrange(key, start or 0, ends or -1)
    end)
    
    if not success then
        print("lrange执行失败: " .. tostring(result))
        return {}
    end
    
    return result or {}
end

-- 优化后的lpush方法（修复bug）
function TRedis:lpush(key, val)
    if not key or #key == 0 or not val then
        return 0
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return 0
    end
    
    local success, result = pcall(function()
        return client:lpush(key, val)
    end)
    
    if not success then
        print("lpush执行失败: " .. tostring(result))
        return 0
    end
    
    return result or 0
end

-- 优化后的rpop方法
function TRedis:rpop(key)
    if not key or #key == 0 then
        return nil
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return nil
    end
    
    local success, result = pcall(function()
        return client:rpop(key)
    end)
    
    if not success then
        print("rpop执行失败: " .. tostring(result))
        return nil
    end
    
    return result
end

-- 新增：获取list长度的方法
function TRedis:llen(key)
    if not key or #key == 0 then
        return 0
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        print("Redis连接失败: " .. tostring(client))
        return 0
    end
    
    local success, result = pcall(function()
        return client:llen(key)
    end)
    
    if not success then
        print("llen执行失败: " .. tostring(result))
        return 0
    end
    
    return result or 0
end

-- 新增：安全获取list指定索引元素的方法
function TRedis:safe_lindex(key, index)
    if not key or #key == 0 then
        return nil, "invalid key"
    end
    
    local len = self:llen(key)
    if len == 0 then
        return nil, "list is empty"
    end
    
    -- 处理负索引
    local actual_index = index
    if index < 0 then
        actual_index = len + index
    end
    
    if actual_index < 0 or actual_index >= len then
        return nil, "index out of range"
    end
    
    local element = self:lindex(key, index)
    return element, nil
end

--删除指定下标的元素
function TRedis:safeRemoveListElement(key, index)
    if not key or #key == 0 then
        return false, "invalid key"
    end
    
    local success, client, redis_lib = pcall(function()
        return self:getRedis()
    end)
    
    if not success then
        return false, "Redis connection failed: " .. tostring(client)
    end
    
    local success, result = pcall(function()
        -- 检查列表长度
        local length = client:llen(key)
        if length == 0 then
            return false, "list is empty"
        end
        
        -- 验证索引范围
        local actual_index = index
        if index < 0 then
            actual_index = length + index
        end
        
        if actual_index < 0 or actual_index >= length then
            return false, "index out of range: " .. index
        end
        
        -- 获取目标元素
        local target_element = client:lindex(key, index)
        if not target_element then
            return false, "element not found at index: " .. index
        end
        
        -- 使用LSET将目标位置设置为临时标记
        local temp_marker = "__DELETE_TEMP_" .. os.time() .. "__"
        client:lset(key, index, temp_marker)
        
        -- 删除临时标记
        local removed_count = client:lrem(key, 1, temp_marker)
        
        return removed_count > 0, "element removed successfully"
    end)
    
    if not success then
        return false, "safeRemoveListElement failed: " .. tostring(result)
    end
    
    return result, "operation completed"
end

-- 优化后的createTaskInfo方法
function TRedis:createTaskInfo(sid, info)
    if not sid or not info then
        return false
    end
    
    return self:hmset1("tasklist", info, sid)
end

-- 关闭Redis连接
function TRedis:close()
    if redis_connection then
        pcall(function()
            redis_connection:close()
        end)
        redis_connection = nil
    end
end
