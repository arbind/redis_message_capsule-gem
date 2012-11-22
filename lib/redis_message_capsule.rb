require "redis_message_capsule/version"
require 'redis'
require 'json'
require 'uri'


# class declaration
module RedisMessageCapsule
  class Configuration
  end
  class Capsule
    class ChannelEmitter
    end
    class ChannelListener
    end
  end
end


###
# module
###
module RedisMessageCapsule
  class << self
    attr_accessor :configuration, :capsules
  end

  def self.config() configuration end
  def self.configure() yield(configuration) if block_given? end
  def self.configuration() @configuration ||=  Configuration.new end

  def self.capsules() @capsules ||=  {} end
  def self.make_capsule_key(url, db_num) "#{url}.#{db_num}" end
  def self.materialize_capsule(redis_url=nil, db_number=-1)
    url = redis_url || config.redis_url    
    redis_uri = URI.parse(url) rescue nil
    return nil if redis_uri.nil?

    db_num = db_number
    db_num = config.db_number if db_num < 0
    key = (make_capsule_key url, db_num)

    capsule = capsules[key] || (Capsule.new redis_uri, db_num)
    capsules[key] = capsule
  end
  def self.capsule(redis_url=nil, db_number=-1) materialize_capsule(redis_url, db_number) end # method alias)

  def self.materialize_redis_client(redis_uri, db_number)
    redis_client = Redis.new(:host => redis_uri.host, :port => redis_uri.port, :password => redis_uri.password) rescue nil
    if redis_client.nil?
      puts "!!!\n!!! Can not connect to redis server at #{uri}\n!!!"
      return nil
    end
    redis_client.select db_number rescue nil
    redis_client
  end

end

class RedisMessageCapsule::Configuration
  attr_accessor :environment, :db_number, :redis_url
  def initialize
    self.environment = ENV["RACK_ENV"] || "development"
    self.db_number = 7 if self.environment.eql? 'production'
    self.db_number = 8 if self.environment.eql? 'development'
    self.db_number = 9 if self.environment.eql? 'test'
    self.db_number ||= 9
    self.redis_url = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
  end
end


class RedisMessageCapsule::Capsule
  attr_accessor :redis_client, :redis_uri, :db_number, :channel_emitters, :channel_listeners

  def initialize(redis_uri, db_number)
    @redis_uri = redis_uri
    @db_number = db_number
    @channel_emitters = {}
    @channel_listeners = {}
    @redis_client = RedisMessageCapsule.materialize_redis_client @redis_uri, @db_number
  end

  def materialize_channel(channel_name) channel_emitters[channel_name] ||= (ChannelEmitter.new channel_name, redis_client) end

  def listen_for(channel_name, &block)
    raise "listen_for(#{channel_name}): No callback was specified!" unless block_given?
    @channel_listeners[channel_name] ||= (ChannelListener.new channel_name, @redis_uri, @db_number)
    @channel_listeners[channel_name].startListening(&block)
  end
  alias_method :on, :listen_for

  # +++ TODO alias_method :off, :stop_listening

end


class RedisMessageCapsule::Capsule::ChannelEmitter
  attr_accessor :channel_name, :redis_client

  def initialize(channel_name, redis_client)
    self.channel_name = channel_name
    self.redis_client = redis_client
  end

  def emit (message)
    payload = { 'data' => message }
    redis_client.rpush channel_name, payload.to_json
  rescue Exception => e
    puts e.message
    puts e.backtrace
  end
  alias_method :send, :emit
  alias_method :message, :emit

end

class RedisMessageCapsule::Capsule::ChannelListener
  def initialize(channel_name, redis_uri, db_number)
    @channel_name = channel_name
    @redis_uri = redis_uri
    @db_number = db_number
    @redis_client = RedisMessageCapsule.materialize_redis_client @redis_uri, @db_number

    @handlers = []
    @listener_thread = nil
  end

  def register(&handler) @handlers << handler end
  def unregister(&handler) @handlers.delete handler end

  def startListening (&handler)
    register(&handler)
    @listener_thread ||= launch_listener
  end

  def launch_listener
    ch_name = @channel_name
    db = @redis_client

    Thread.new do
      Thread.current[:name] = :RedisMessageCapsule
      Thread.current[:chanel] = ch_name
      Thread.current[:description] = "Listening for '#{ch_name}' messages from #{@redis_uri} "
      Thread.current[:redis_client] = db

      loop do # listen forever
        channel_element = db.blpop ch_name, 0 # pop a message, or block the thread and wait till the next one
        ch = channel_element.first
        element = channel_element.last
        payload = ( JSON.parse(element) rescue {'data' => 'error parsing json!'} )
        message = payload['data']
        @handlers.each { |handler| handler.call(message) }
      end #loop
    end # Thread.new
  end # launce_listener
end # class