local t = require('luatest')
local h = require('test.helper')
local g = t.group()

local fio = require('fio')
local bus = require('bus')
local fiber = require('fiber')
local netbox = require('net.box')

g.before_all(function()
    g.server = t.Server:new({
        workdir = fio.tempdir(),
        alias = 'dummy',
        command = h.entrypoint('srv_basic'),
        net_box_port = 13301,
    })

    g.server:start()

    h.retrying({}, function()
        g.server:connect_net_box()
    end)
end)

g.after_all(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

-- [x] test conn created with wait_connected false
-- [x] is it possible to subscribe twice with a same key within a single
--   connection with different handlers?
-- [x] Subscribe on a dead connection
-- [x] Subscribe on a hanging connection (with a timeout?)
-- [ ] Reject right after subscribing
-- [ ] Renew before the function is started
-- [ ] Idempotency
-- [ ] Multiple renews should be stacked
-- [ ] renew + reject
-- [ ] reject + renew
-- [x] two parallel susbscriptions shouldn't affect each other
-- [ ] sub:renew() doesn't yield
-- [ ] sub:reject() doesn't yield
-- [ ] what if callback raises an error
-- [ ] ??? fiber.sleep(100) in a callback doesn't affect other subscriptions
-- [ ] multiple broadcast API
-- [ ] test single broadcast for two different connections
-- [ ] broadcast doesn't yield
-- [ ] test GC on conn closed
-- [ ] who refcounts subscription?
-- [x] test initial value
-- [x] test values stacking

function g.test_connection()
    local fn_void = function() end

    -- Regular subscribe
    local conn = netbox.connect(g.server.net_box_uri)
    t.assert_equals(conn.state, 'active')
    local sub, err = bus.subscribe(conn, 'key', fn_void)
    t.assert_not(err)
    t.assert(sub)
    conn:close()

    -- Subscribe with wait_connected = false
    local conn = netbox.connect(g.server.net_box_uri, {wait_connected = false})
    t.assert_equals(conn.state, 'initial')
    local sub, err = bus.subscribe(conn, 'key', fn_void)
    t.assert_not(err)
    t.assert(sub)
    conn:close()

    -- Connection refused
    local conn = netbox.connect('localhost:9', {wait_connected = false})
    t.assert_equals(conn.state, 'initial')
    t.assert_error_msg_equals('Connection refused',
        bus.subscribe, conn, 'key', fn_void
    )
    conn:close()

    -- TODO: bus.subscribe({is_async = true})
end

function g.test_timeout()
    local conn = netbox.connect(g.server.net_box_uri)
    t.assert_equals(conn.state, 'active')

    local ticker = 0

    g.server.process:kill('STOP')

    t.assert_error_msg_equals('Timeout exceeded',
        bus.subscribe, conn, 'key', function(sub)
            ticker = ticker + 1
            sub:renew()
        end, {timeout = 0.1}
    )
    conn:close()

    -- Callback shouldn't be triggered if subscribe didn't succeed
    g.server.process:kill('CONT')
    g.server.net_box:ping()
    fiber.yield()
    t.assert_equals(ticker, 0)
end

function g.test_one_subscription()
    local conn = netbox.connect(g.server.net_box_uri)
    local chan = fiber.channel()

    local function broadcast(...)
        return conn:call('package.loaded.bus.broadcast', {...})
    end

    local csw1 = h.fiber_csw()
    local sub, _ = bus.subscribe(conn, 'key', function(sub)
        chan:put({sub.key, sub.value})
    end)
    local csw2 = h.fiber_csw()
    t.assert_equals(csw2, csw1 + 1)

    t.assert_equals(chan:get(0.1), {'key', nil})

    sub:renew()
    broadcast('key', 1)
    t.assert_equals(chan:get(0.1), {'key', 1})

    broadcast('key', 2)
    t.assert_equals({chan:get(0.1)}, {nil})

    -- two events shuld be stacked, only the
    -- last one arrives to the client
    sub:renew()
    broadcast('key', 3)
    t.assert_equals(chan:get(0.1), {'key', 3})
end

function g.test_two_subscriptions()
    local conn = netbox.connect(g.server.net_box_uri)
    local tbl = {}
    -- It's possible to subscrive for the same key twice in a single connection
    bus.subscribe(conn, 'same_key', function(sub) tbl['fn1'] = sub.value sub:renew() end)
    bus.subscribe(conn, 'same_key', function(sub) tbl['fn2'] = sub.value sub:renew() end)

    h.run_remotely(conn, function()
        require('bus').broadcast('same_key', true)
    end)

    h.retrying({}, function()
        t.assert_equals(tbl, {fn1 = true, fn2 = true})
    end)

    h.run_remotely(conn, function()
        require('bus').broadcast('same_key', 2)
    end)

    h.retrying({}, function()
        t.assert_equals(tbl, {fn1 = 2, fn2 = 2})
    end)
end

-- function g.test_renew()
--     local sub, err = bus.subscribe(conn, 'test_reject', fn_void())

--     sub:renew()
--     sub:renew()
-- end

-- function g.test_reject()
--     -- Reject prevents further callback invocations
--     -- Reject doesn't yield

--     local conn = netbox.connect(g.server.net_box_uri)
--     local ticker = 0

--     h.run_remotely(conn, function()
--         require('bus').broadcast('test_reject', 'v1')
--     end)

--     local sub, err = bus.subscribe(conn, 'test_reject', function(sub)
--         ticker = ticker + 1
--         sub:renew()
--     end)
--     t.assert_not(err)
--     t.assert_equals(ticker, 0)
--     t.assert_equals(sub.value, 'v1')

--     local csw1 = h.fiber_csw()
--     sub:reject()
--     local csw2 = h.fiber_csw()
--     t.assert_equals(csw2, csw1)

--     h.run_remotely(conn, function()
--         require('bus').broadcast('test_reject', 'v2')
--     end)

--     g.server.net_box:ping()
--     fiber.yield()
--     t.assert_equals(ticker, 0, 'callback fired after reject')
-- end
