#!/usr/bin/env tarantool

local netbox = require('net.box')
local bus = require('bus')

function _G.log_event(sub)
	package.loaded.log.info(
        '%s:%s: %s = %s',
        sub.conn.host or '', sub.conn.port,
        sub.key, sub.value
    )
    sub:renew()
end

local conn = netbox.connect('localhost:3301')
_G.sub1 = bus.subscribe(conn, 'box.info.ro', _G.log_event)
_G.sub2 = bus.subscribe(conn, 'demo.random', _G.log_event)
