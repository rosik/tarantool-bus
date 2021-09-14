require('strict').on()

local h = table.copy(require('luatest.helpers'))
local fio = require('fio')
local fiber = require('fiber')

h.project_root = fio.dirname(debug.sourcedir())

function h.entrypoint(name)
    local path = fio.pathjoin(
        h.project_root, 'test', string.format('%s.lua', name)
    )
    if not fio.path.exists(path) then
        error(path .. ': no such entrypoint', 2)
    end
    return path
end

function h.fiber_csw()
    --- Get fiber context switches number
    return fiber.info()[fiber.id()].csw
end

--- Verify function closure.
--
-- Raise an error when expectations aren't met.
--
-- @function assert_upvalues
-- @local
-- @tparam function fn
-- @tparam {string,...} upvalues
-- @raise "Unexpected upvalues"
-- @usage
--   local x, y
--   local function foo() return x, y end
--   assert_upvalues(foo, {'x'})
--   -- error: Unexpected upvalues, [x] expected, got [x, y]
function h.assert_upvalues(fn, ups)
    local got = {}
    for i = 1, debug.getinfo(fn, 'u').nups do
        got[i] = debug.getupvalue(fn, i)
    end

    table.sort(got)
    table.sort(ups)

    if #got ~= #ups then goto fail end
    for i = 1, #ups do
        if got[i] ~= ups[i] then goto fail end
    end

    do return end

    ::fail::
    local err = string.format(
        'Unexpected upvalues, [%s] expected, got [%s]',
        table.concat(ups, ', '), table.concat(got, ', ')
    )
    error(err, 2)
end

function h.run_remotely(conn, fn)
    h.assert_upvalues(fn, {})

    local ok, ret = conn:eval([[
        local fn = loadstring(...)
        return pcall(fn)
    ]], {string.dump(fn)})

    if not ok then
        error(ret, 0)
    end

    return ret
end


return h
