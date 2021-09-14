local t = require'luatest'
local fio = require'fio'
local bus = require'bus'
local netbox = require'net.box'

local g = t.group()

g.before_all(function()
    local tempdir = fio.tempdir()
    box.cfg({
        memtx_dir = tempdir,
        wal_dir = tempdir,
        wal_mode = 'none',
    })

    g.tempdir = tempdir

    box.schema.user.grant('guest', 'super', nil, nil, {if_not_exists = true})
    box.cfg({
        listen = 13301,
    })

end)

g.after_all(function()
    fio.rmtree(g.tempdir)
end)

g.test_recv_message = function()
    local sent_message = 'test_message'
    local conn = netbox.connect('localhost:13301')
    local sub_obj
    bus.subscribe(conn, 'test', function(sub)
        sub_obj = table.copy(sub)
        sub:renew()
    end)

    bus.broadcast('test', sent_message)
    t.helpers.retrying({}, function()
        t.assert_equals(sub_obj.value, sent_message)
        t.assert_equals(sub_obj.key, 'test')
        t.assert_equals(sub_obj.conn.host, 'localhost')
        t.assert_equals(sub_obj.conn.port, '13301')
    end)
end
