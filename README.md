# redis_cluster

This is the straight port of https://github.com/zhchsf/redis_cluster gem for Ruby to Crystal

It doesn't tested well yet, so use it on your own risk.
However it works for me :-)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  redis_cluster:
    github: relonger/crystal_redis_cluster
```

## Usage

```crystal
require "redis_cluster"
```

Watch examples how to use at https://github.com/zhchsf/redis_cluster page


## TODO
- Port spec's and run tests
- Update up to last 0.2.9 changes on original gem

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
