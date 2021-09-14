.PHONY: deps
.rocks: deps
	tarantoolctl rocks install luatest 0.5.4
	tarantoolctl rocks install luacov 0.13.0
	tarantoolctl rocks install luacheck 0.26.0

.PHONY: test
test:
	.rocks/bin/luatest
