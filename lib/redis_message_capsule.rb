require "redis_message_capsule/version"
require 'redis'
require 'json'
require 'uri'

module RedisMessageCapsule
  class Configuration
    attr_accessor :environment, :db_number, :redis_url

    def initialize
      self.environment = ENV["RACK_ENV"] || "development"
      self.db_number = 7 if self.environment.eql? 'production'
      self.db_number = 8 if self.environment.eql? 'development'
      self.db_number = 9 if self.environment.eql? 'test'
      self.db_number ||= 9
      self.redis_url = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://localhost:6379/"
    end
  end

  class << self
    attr_accessor :configuration, :redis_clients, :capsule_channels, :listener_threads, :handlers
  end

  def self.redis_clients
    @redis_clients ||=  {}
  end

  def self.capsule_channels
    @capsule_channels ||=  {}
  end

  def self.listener_threads
    @listener_threads ||=  {}
  end

  def self.configuration
    @configuration ||=  Configuration.new
  end
  def self.config() configuration end

  def self.configure
    yield(configuration) if block_given?
  end

  class Channel
    attr_accessor :name, :redis_client
    def initialize(name, redis_client)
      self.name = name
      self.redis_client = redis_client
    end

    def send (message)
      payload = { 'data' => message }
      redis_client.rpush name, payload.to_json
    end

  end

  def self.make_client_key(url, db_num)
    "#{url}.#{db_num}"
  end

  def self.make_channel_key(name, url, db_num)
    "#{name}.#{url}.#{db_num}"
  end

  def self.make_listener_key(channels, url, db_num)
    [ *channels, url, db_num].join('.')
  end

  def self.channel(name, redis_url=nil, db_number=-1)
    url = redis_url || config.redis_url
    db_num = db_number
    db_num = config.db_number if db_num < 0

    channel_key = make_channel_key(name, url, db_num)
    return capsule_channels[channel_key] unless capsule_channels[channel_key].nil?

    client_key = make_client_key(url, db_num)
    redis_client = redis_clients[client_key]

    if redis_client.nil?
      uri = URI.parse(url)
      redis_client = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password) rescue nil
      if redis_client.nil?
        puts "!!!\n!!! Can not connect to redis server at #{uri}\n!!!"
        return nil
      end
      redis_client.select db_num
      redis_clients[client_key] = redis_client
    end
    channel = Channel.new(name, redis_client)
    capsule_channels[channel_key] = channel
    channel
  end


  def self.listen(channels_array, redis_url=nil, db_number=-1)
    url = redis_url || config.redis_url
    db_num = db_number
    db_num = config.db_number if db_num < 0
    channels = *channels_array
    key = make_listener_key(channels, url, db_number)
    return true unless listener_threads[key].nil?
    
    listener_threads[key] = Thread.new do
      Thread.current[:name] = :RedisMessageCapsule
      Thread.current[:description] = "Listening for messages from #{url.to_s} on chanel: #{[*channels].join(',')} "

      redis_client = nil # establish redis connection: 
      until !redis_client.nil? and redis_client.ping
        uri = URI.parse(url)
        redis_client = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password) rescue nil
        if redis_client.nil?
          puts "!!!\n!!! Can not connect to redis server at #{uri}\n!!!"
          sleep 10
        else
          redis_client.select db_num
          puts "connected!"
          Thread.current[:redis_client] = redis_client
        end
      end

      puts "Listening for messages on #{[*channels].join(', ')}"
      loop do
        channel_element = redis_client.blpop *channels, 0
        channel = channel_element.first
        element = channel_element.last
        payload = ( JSON.parse(element) rescue {} )
        message = payload['data']
        # fire event on channel
        puts "#{channel}: #{message}"
        yield(message) if block_given?
      end
    end
  end

end


def start_redis_listeners(channels_array, redis_url=nil)
  channels = *channels_array

  url = redis_url || ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://localhost:6379/"
  key = url.to_s + channels.to_s
end
