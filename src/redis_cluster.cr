require "./redis_cluster/version"
require "redis"

module RedisCluster
  alias HostOptions = NamedTuple(host: String, port: Int32, unixsocket: String?, password: String?, database: Int32?, url: String?)

  def self.host(host = "localhost", port = 6379, unixsocket : String? = nil, password : String? = nil, database : Int32? = nil, url : String? = nil)
    return HostOptions.new(host: host, port: port, unixsocket: unixsocket, password: password, database: database, url: url)
  end

  alias GlobalOptions = NamedTuple(password: String?, database: Int32?)

  # startup_hosts examples:
  #   [{host: 'xxx', port: 'xxx'}, {host: 'xxx', port: 'xxx'}, ...]
  # global_configs:
  #   options for redis: password, ...
  def self.new(startup_hosts : Array(HostOptions), password = nil, database = nil) : Client
    @@client = Client.new(startup_hosts, GlobalOptions.new(password: password, database: database))
  end

  def self.merge_options(host : HostOptions, global : GlobalOptions) : HostOptions
    hosts = HostOptions.new(host: host[:host], port: host[:port], unixsocket: host[:unixsocket], url: host[:url],
      password: host[:password] || global[:password],
      database: host[:database] || global[:database])
  end
end

require "./redis_cluster/configuration"
require "./redis_cluster/client"
require "./redis_cluster/node"
require "./redis_cluster/pool"
require "./redis_cluster/slot"
require "./redis_cluster/crc16"
require "./redis_cluster/errors"
