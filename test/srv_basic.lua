#!/usr/bin/env tarantool

local log = require('log')
local bus = require('bus')
local fiber = require('fiber')

fiber.create(function()
    fiber.name('monitor::box.info.ro')
    if type(box.cfg) == 'function' then
        box.ctl.wait_ro()
        log.info('RO')
    end

    while true do
        bus.broadcast('box.info.ro', box.info.ro)
        if box.info.ro then
            box.ctl.wait_rw()
            log.info('RW')
        else
            box.ctl.wait_ro()
            log.info('RO')
        end
    end
end)

local workdir = os.getenv('TARANTOOL_WORKDIR')
box.cfg({
    memtx_dir = workdir,
    wal_dir = workdir,
    wal_mode = 'none',
})

box.schema.user.grant('guest', 'super', nil, nil, {if_not_exists = true})
box.cfg({
    listen = os.getenv('TARANTOOL_LISTEN'),
})

function _G.roll()
    bus.broadcast('demo.random', math.random(6))
end
