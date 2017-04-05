module RedisCluster
  class Node
    # slots is a range array: [1..100, 300..500]
    property :slots

    #
    # basic requires:
    #   {host: xxx.xxx.xx.xx, port: xxx}
    # redis cluster don't support select db, use default 0
    #
    @connection : Redis?

    def initialize(opts : HostOptions)
      @options = opts
      @slots = [] of Range(Int32, Int32)
    end

    def name
      "#{@options[:host]}:#{@options[:port]}"
    end

    def host_hash
      {host: @options[:host], port: @options[:port]}
    end

    def has_slot?(slot)
      slots.any? { |range| range.includes? slot }
    end

    def asking
      connection.void_command(["ASKING"])
    end

    def connection : Redis
      @connection = Node.redis(**@options) unless @connection
      return @connection.as(Redis)
    end

    macro method_missing(call)
      #puts "Node.#{connection}.{{call.name.id}}({{*call.args}})"
      connection.{{call.name.id}}({{*call.args}})
    end

    def self.redis(**options) : Redis
      ::Redis.new(**options) # , timeout: Configuration::DEFAULT_TIMEOUT
    end
  end # end Node

end
