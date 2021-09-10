# Pub/Sub over Tarantool net.box

## Running demo

1. Run `./demo-server.lua` and `./demo-client.lua` in two adjasent terminal windows.
2. Roll a dice in server console: `roll()`.

```console
$ ./demo-client.lua
localhost:3301: box.info.ro = false
localhost:3301: demo.random = nil
entering the event loop
localhost:3301: demo.random = 5
localhost:3301: demo.random = 5
localhost:3301: demo.random = 4
localhost:3301: demo.random = 5
localhost:3301: demo.random = 1
localhost:3301: demo.random = 4
localhost:3301: demo.random = 3
```


