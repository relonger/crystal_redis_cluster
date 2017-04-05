module RedisCluster
  class Pool
    getter :nodes, :global_configs

    # @global_configs : Hash(Symbol, String | Int32 | Nil)
    # @global_configs : Options

    def initialize(@global_configs : GlobalOptions)
      @nodes = [] of Node
      # @global_configs = global_configs
    end

    # TODO: type check
    def add_node!(node_options : HostOptions, slots)
      new_node = Node.new(RedisCluster.merge_options(node_options, global_configs))
      node = @nodes.find { |n| n.name == new_node.name } || new_node
      node.slots = slots
      @nodes.push(node).uniq!
    end

    def delete_except!(master_hosts)
      names = master_hosts.map { |host, port| "#{host}:#{port}" }
      @nodes.reject! { |n| !names.includes?(n.name) }
    end

    # other_options:
    #   asking
    #   random_node
    {% for method_name in Configuration::SUPPORT_SINGLE_NODE_METHODS %}
      def {{method_name.id}}(*args, asking=false, random_node=false)
        #puts "Pool.#{{{method_name}}}(#{args})"
        {% if method_name == "eval" %}
            key = args[1].as(Array)[0]
        {% elsif ["info", "exec", "slaveof", "config", "shutdown"].includes?(method_name) %}
            nil
         {% else %}
            key = args.first
        {% end %}

        if key.nil?
          raise NotSupportError.new
        else
          node = random_node ? random_node() : node_by(key)
          #puts "Selected node: #{node.name}"
          if node
            node.asking if asking
            node.{{method_name.id}}(*args)
          else
            raise Exception.new("No Redis Nodes Found")
          end
        end
      end
    {% end %}

    def keys(glob, &block)
      on_each_node(:keys, glob).flatten
    end

    # Now mutli & pipelined conmand must control keys at same slot yourself
    # You can use hash tag: "{foo}"
    def multi(&block)
      random_node.multi(&block)
    end

    def pipelined(&block)
      random_node.pipelined(&block)
    end

    private def node_by(key)
      slot = Slot.slot_by(key)
      @nodes.find { |node| node.has_slot?(slot) }
    end

    private def random_node
      @nodes.sample
    end

    macro on_each_node(method, *args)
      empty_block = ->{}
      @nodes.map do |node|
        node.{{method.id}}(*args)
        # node.execute(method, args, &empty_block)
      end
    end
  end # end pool

end
