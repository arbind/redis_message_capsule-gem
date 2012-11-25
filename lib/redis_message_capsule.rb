require "redis_message_capsule/version"
require 'redis'
require 'json'
require 'uri'


# class declaration
module RedisMessageCapsule
  class Configuration
  end
  class Capsule
    class Channel
      class Listener
      end
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
  attr_accessor :environment, :redis_url, :db_number
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
  attr_accessor :redis_client, :redis_uri, :db_number, :channels

  def initialize(redis_uri, db_number)
    @redis_uri = redis_uri
    @db_number = db_number
    @channels = {}
    @redis_client = RedisMessageCapsule.materialize_redis_client @redis_uri, @db_number
  end

  def materialize_channel(channel_name)
    channels[channel_name] ||= (Channel.new channel_name, redis_client, redis_uri, db_number)
  end
  alias_method :channel, :materialize_channel
  alias_method :make_channel, :materialize_channel
  alias_method :create_channel, :materialize_channel

end

class RedisMessageCapsule::Capsule::Channel
  attr_accessor :channel_name, :listener, :redis_client, :redis_uri, :db_number

  def initialize(channel_name, redis_client, redis_uri, db_number )
    self.channel_name = channel_name
    self.redis_client = redis_client
    self.redis_uri = redis_uri
    self.db_number = db_number
    @listener = nil
  end

  def send (message)
    payload = { 'data' => message }
    redis_client.rpush channel_name, payload.to_json
  rescue Exception => e
    puts e.message
    puts e.backtrace
  ensure
    self # chainability
  end
  alias_method :emit, :send
  alias_method :message, :send

  def register(&block)
    raise "listen_for(#{channel_name}): No callback was specified!" unless block_given?
    @listener ||= (Listener.new channel_name, redis_uri, db_number) # listener needs its own connection since it blocks
    @listener.register(&block)
    self # chainability
  end
  alias_method :on, :register
  alias_method :listen, :register

  def unregister(&block)
    # +++
  end

  def stop_listening
    # +++
  end

end

class RedisMessageCapsule::Capsule::Channel::Listener
  def initialize(channel_name, redis_uri, db_number)
    @channel_name = channel_name
    @redis_uri = redis_uri
    @db_number = db_number
    @handlers = []
    @listener_thread = nil
  end

  def register(&handler)
    @handlers << handler
    launch_listener if @listener_thread.nil?
    handler
  end

  def stop_listening
    @listener_thread[:listening] = false unless @@listener_thread.nil?
  end

  def unregister(&handler) @handlers.delete handler end

  def launch_listener
    @listener_thread ||= Thread.new do

      blocking_redis_client = RedisMessageCapsule.materialize_redis_client @redis_uri, @db_number
      # This redis connection will block when popping, so it is created inside of its own thread 

      Thread.current[:name] = :RedisMessageCapsule
      Thread.current[:chanel] = @channel_name
      Thread.current[:description] = "Listening for '#{@channel_name}' messages from #{@redis_uri}"
      Thread.current[:redis_client] = blocking_redis_client
      Thread.current[:listening] = true

      while Thread.current[:listening] do # listen forever
        begin
          channel_element = blocking_redis_client.blpop @channel_name, 0 # pop a message, or block the thread and wait till the next one
          unless channel_element.nil?
            ch = channel_element.first
            element = channel_element.last
            payload = ( JSON.parse(element) rescue {'data' => 'error parsing json!'} )
            message = payload['data']
            @handlers.each { |handler| handler.call(message) }
          end
        rescue Exception => e
          Thread.current[:listening] = false # stop listening
        end
      end # while
    end # Thread.new
  end # launch_listener

end # class
