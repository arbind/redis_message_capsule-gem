require "redis_message_capsule/version"
require 'redis'
require 'json'
require 'uri'

###
# module
###
module RedisMessageCapsule
  class << self
    attr_accessor :configuration, :capsules
  end

###
# Configuration
###
  def self.config() configuration end
  def self.configure() yield(configuration) if block_given? end
  def self.configuration() @configuration ||=  Configuration.new end

  class Configuration
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

###
# Capsule
###
  def self.capsules() @capsules ||=  {} end
  def self.make_capsule_key(url, db_num) "#{url}.#{db_num}" end
  def self.materialize_capsule(redis_url=nil, db_number=-1)
    url = redis_url || config.redis_url
    db_num = db_number
    db_num = config.db_number if db_num < 0
    key = (make_capsule_key url, db_num)
    capsule = capsules[key] || (Capsule.new url, db_num)
    capsules[key] = capsule
  end
  # alias_method :capsule, :materialize_capsule
  # alias_method :make_capsule, :materialize_capsule
  # alias_method :create_capsule, :materialize_capsule

  class Capsule
    attr_accessor :redis_url, :db_number, :open_channels, :listener_threads, :handlers

    def initialize(redis_url, db_number)
      self.redis_url = redis_url
      self.db_number = db_number
    end

###
# Capsule Channel Emitter
###
    def open_channels() @open_channels ||=  {} end

    class Channel
      attr_accessor :name, :redis_client

      def initialize(name, redis_client)
        self.name = name
        self.redis_client = redis_client
      end

      def emit (message)
        payload = { 'data' => message }
        redis_client.rpush name, payload.to_json
      rescue Exception => e
        puts e.message
        puts e.backtrace
      end
      alias_method :send, :emit

    end

    def materialize_channel(name)
      return open_channels[name] unless open_channels[name].nil?

      uri = URI.parse(redis_url)
      redis_client = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password) rescue nil
      if redis_client.nil?
        puts "!!!\n!!! Can not connect to redis server at #{uri}\n!!!"
        return nil
      end
      redis_client.select db_number rescue (return nil)
      open_channels[name] = (Channel.new name, redis_client)
    end
    alias_method :channel, :materialize_channel
    alias_method :make_channel, :materialize_channel
    alias_method :create_channel, :materialize_channel

###
# Capsule Listener
###
    def listener_threads() @listener_threads ||=  {} end

    def listen_for(channel_name)
      raise "listen_for(#{channel_name}): No callback was specified!" unless block_given?
      # +++ check if thread is alive, if it already exists
      return listener_threads[channel_name] unless listener_threads[channel_name].nil?
      
      listener_threads[channel_name] = Thread.new do
        Thread.current[:name] = :RedisMessageCapsule
        Thread.current[:description] = "Listening for messages from #{redis_url} on channel: #{channel_name} "

        redis_client = nil # establish redis connection: 
        until !redis_client.nil? and redis_client.ping
          uri = URI.parse(redis_url)
          redis_client = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password) rescue nil
          if redis_client.nil?
            puts "!!!\n!!! Can not connect to redis server at #{uri}\n!!!"
            sleep 10
          else
            redis_client.select db_number
            Thread.current[:redis_client] = redis_client
          end
        end

        loop do # listen forever
          channel_element = redis_client.blpop channel_name, 0 # pop a message, or block the thread and wait till the next one
          channel = channel_element.first
          element = channel_element.last
          payload = ( JSON.parse(element) rescue {'data' => 'error parsing json!'} )
          message = payload['data']
          yield(message) if block_given? # fire event on channel
        end
      end # Thread.new
    end # listen_for
    alias_method :on, :listen_for
    alias_method :listen, :listen_for
    alias_method :listen_to, :listen_for

  end

end
