require "thread"

module RedisCluster
  class Client
    def initialize(startup_hosts : Array(HostOptions), global_configs : GlobalOptions)
      @startup_hosts = startup_hosts
      @pool = Pool.new(global_configs)
      @mutex = Mutex.new
      reload_pool_nodes(true)
    end

    {% for method_name in Configuration::SUPPORT_SINGLE_NODE_METHODS %}
       def {{method_name.id}}(*args)
        ttl = Configuration::REQUEST_TTL
        asking = false
        try_random_node = false

        while ttl > 0
          ttl -= 1
          begin
            return @pool.{{method_name.id}}(*args, asking: asking, random_node: try_random_node)
          #rescue Errno::ECONNREFUSED | Redis::TimeoutError | Redis::CannotConnectError | Errno::EACCES
          rescue Redis::DisconnectedError
            puts "!!! Redis::DisconnectedError. Retry with random node"
            try_random_node = true
            sleep 0.1 if ttl < Configuration::REQUEST_TTL/2
          rescue e : Exception
            puts "!!! Got Exception from redis: #{e} (#{e.class})"
            err_code = e.to_s.split.first
            raise e unless {"MOVED", "ASK"}.includes?(err_code)

            if err_code == "ASK"
              asking = true
            else
              reload_pool_nodes
              sleep 0.1 if ttl < Configuration::REQUEST_TTL/2
            end
          end
        end
        raise Exception.new("Redis Cluster Failed")
       end
    {% end %}

    private def reload_pool_nodes(raise_error = false)
      # return @pool.add_node!(@startup_hosts, [(0..Configuration::HASH_SLOTS)]) unless @startup_hosts.is_a? Array

      @mutex.synchronize do
        @startup_hosts.each do |options|
          begin
            redis = Node.redis(**RedisCluster.merge_options(options, @pool.global_configs))
            slots_mapping = Hash({String, Int32}, Array(Range(Int32, Int32))).new { |h, k| h[k] = Array(Range(Int32, Int32)).new }

            redis.string_array_command(["CLUSTER", "SLOTS"]).each { |item|
              from, to, host_info = item.as(Array)

              from, to = from.as(Int).to_i32, to.as(Int).to_i32
              host_info = host_info.as(Array)
              host_info = {host_info[0].as(String), host_info[1].as(Int).to_i32}

              slots_mapping[host_info].push((from..to))
            }
            # pp "CLUSTER:", slots_mapping

            @pool.delete_except!(slots_mapping.keys)
            slots_mapping.each do |host, slots_ranges|
              @pool.add_node!(RedisCluster.host(host: host[0], port: host[1]), slots_ranges)
            end
          rescue e : Redis::Error
            raise e if raise_error && e.message =~ /cluster\ support\ disabled$/
            raise e if e.message =~ /NOAUTH\ Authentication\ required/
            next
          rescue
            next
          end
          break
        end
        fresh_startup_nodes
      end
    end

    def fresh_startup_nodes
      @pool.nodes.each { |node| @startup_hosts.push(RedisCluster.host(**node.host_hash)) }
      @startup_hosts.uniq!
    end
  end # end client

end
