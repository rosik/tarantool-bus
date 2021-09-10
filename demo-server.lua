#!/usr/bin/env tarantool

local fio = require('fio')
local bus = require('bus')
local fiber = require('fiber')

fiber.create(function()
    fiber.name('monitor::box.info.ro')
    if type(box.cfg) == 'function' then
        box.ctl.wait_ro()
    end

    while true do
        bus.broadcast('box.info.ro', box.info.ro)
        if box.info.ro then
            box.ctl.wait_rw()
        else
            box.ctl.wait_ro()
        end
    end
end)

local tempdir = fio.tempdir()
box.cfg({
    memtx_dir = tempdir,
    wal_dir = tempdir,
    wal_mode = 'none',
})
fio.rmtree(tempdir)

box.schema.user.grant('guest', 'super', nil, nil, {if_not_exists = true})
box.cfg({
    listen = 3301,
})

function _G.roll()
    bus.broadcast('demo.random', math.random(6))
end

require('console').start()
