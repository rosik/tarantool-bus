local fiber = require('fiber')

local sub_mt = {
    __type = 'net.sub',
    __index = {
        renew = function(sub) sub.__ctl:put('renew') end,
        reject = function(sub) sub.__ctl:put('reject') end,
    }
    -- TODO
    -- __gc = sub_reject,
}

local function sub_loop(sub)
    while true do
        sub:callback()
        fiber.testcancel()

        local action = sub.__ctl:get()
        if action == 'renew' then
            local ret = sub.conn:call('srv_resubscribe', {sub.key, sub.version})
            sub.value = ret.value
            sub.version = ret.version
        elseif action == 'reject' then
            sub.conn:call('srv_unsubscribe', {sub.key}, {is_async = true})
            break
        else
            assert(false, 'API violation')
        end
    end
end

local function subscribe(conn, key, callback, opts)
    -- local auto_renew = opts and opts.auto_renew
    -- if auto_renew == nil then
    --     auto_renew = true
    -- end

    local ret, err = conn:call('srv_subscribe', {key}, opts)

    if ret == nil then
        return nil, err
    end

    local sub = setmetatable({
        key = key,
        conn = conn,
        value = ret.value,
        version = ret.version,
        callback = callback,
        -- auto_renew = auto_renew,
        __ctl = fiber.channel(1),
    }, sub_mt)

    local f = fiber.new(sub_loop, sub)
    f:name(('sub::%s'):format(key))
    sub.__loop = f

    return sub
end

local vault = {} -- [key] = {value = value, version = version}
setmetatable(vault, {
    __index = function(tbl, key)
        rawset(tbl, key, {version = 0})
        return tbl[key]
    end
})

local key_cond = {} -- [key] = fiber.cond()
setmetatable(key_cond, {
    __index = function(tbl, key)
        rawset(tbl, key, fiber.cond())
        return tbl[key]
    end
})

function _G.srv_subscribe(key)
    return vault[key]
end

function _G.srv_resubscribe(key, version)
    -- TODO fiber remains suspended even after connection is closed
    if vault[key].version <= version then
        key_cond[key]:wait()
    end

    return vault[key]
end

function _G.srv_unsubscribe(_)
end

local function broadcast(key, value)
    package.loaded.log.info('%s = %s', key, value)

    local rec = vault[key]
    rec.value = value
    rec.version = rec.version + 1
    key_cond[key]:broadcast()
end

return {
    subscribe = subscribe,
    broadcast = broadcast,
    internal = {
        vault = vault,
        key_cond = key_cond,
    }
}
