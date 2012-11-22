# RedisMessageCapsule

Send messages between node or rails apps asynchronously (via redis).
* [report an issue with the ruby version] (https://github.com/arbind/redis_message_capsule/issues)
* [report an issue with the node version] (https://github.com/arbind/redis_message_capsule-node/issues)

## Installation (with npm for node) (as a gem for ruby)

    $ npm install redis_message_capsule
    $ gem install redis_message_capsule

## Demonstration
* Make sure redis is running
* Data or object being sent will automatically be serialized to json (in order to teleport through redis)
  * in node: using obj.toJSON() or JSON.stringify(obj)
  * in rails: using obj.to_json 
* Demo for node <-> node: Open 2 terminal windows to send messages between 2 node apps  (outlined below)
* Demo for ruby <-> ruby: Open 2 terminal windows to send messages between 2 ruby apps  (outlined below)
* Demo for node <-> ruby: Open 4 terminal windows and do both of the demos above (which are outlined below)
* Think of each window that you open as a stand-alone app

### Demo for node <-> node
In node window 1 - emit messages from cat:

    $ node
    RedisMessageCapsule = require('redis-message-capsule')
    //
    // materialize a message capsule bound to a redis db
    redisURL = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.materializeCapsule(redisURL)
    //
    // create a cat channel to send messages on, and start meowing
    cat = capsule.materializeChannel('cat')
    cat.emit('meow')    // will show up in node window 2 (listening to cat)
    cat.emit('meow')    // will show up in node window 2 (listening to cat)
 
In node window 2 - listen for cat messages, emit messages from dog:

    $ node
    RedisMessageCapsule = require('redis-message-capsule')
    redisURL = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.materializeCapsule(redisURL)
    //
    // start listening for cat messages
    capsule.listenFor('cat', function(err, message){ console.log(message) }  ) 
    // => meow
    // => meow    
    // create a dog channel to send messages to ruby, and start barking
    dog = capsule.materializeChannel('dog')
    dog.emit('woof')  // will show up in ruby window 2 (listening to dog)

In node window 1 - send more cat messages:

    talk = { say: 'roar', time: new Date() }
    cat.emit(9)
    cat.emit( talk )
    // Watch for real-time messages show up in node window 2:
    // => 9 
    // => {"say"=>"roar", "time"=>"2012-11-21 08:08:08 -0800"} 

###  Demo for ruby <-> ruby
In ruby window 1 - emit dog messages:

    $ irb
    require 'redis_message_capsule'
    #
    # materialize a message capsule bound to a redis db
    redisURL = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    capsule = RedisMessageCapsule.materialize_capsule redisURL
    #
    # create a dog channel to send messages on, and start barking
    dog = capsule.materialize_channel 'dog'
    dog.emit 'bark'

In ruby window 2 -  listen for dog messages in ruby and emit cat messages:

    $ irb
    require 'redis_message_capsule'
    redisURL = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    capsule = RedisMessageCapsule.materialize_capsule redisURL
    capsule.listen_for('dog') do |msg| 
        puts "#{msg}!" * 2
    end
    # => woof!woof!
    # => bark!bark!
    # create a cat channel to send messages to node
    cat = capsule.materialize_channel 'cat'
    cat.emit 'purrr' # will show up in node window 2 (listening to cat)

Back in ruby window 1 - send more dog messages:

    talk = { say: 'grrrrrr', time: new Date() }
    dog.emit 2      # will show up in window 4 (listening to dog)
    dog.emit talk   # will show up in window 4 (listening to dog)
    # Watch for real-time messages to show up in ruby window 2:
    # => 2 
    # => {"say"=>"grrrrrr", "time"=>"2012-11-21 08:08:08 -0800"} 
    # => purr

## Environment
In order for 2 apps to send messages to each other, they must select the same redis db number.

By default, RedisMessageCapsule will: 
* select 9 for test environment
* select 8 for development environment
* select 7 for production environment
The selected db can also be overriden when materializing a capsule  (examples are below).

If 2 apps are not sending messages to each other:
* check that they are both in the same environment (test, development, production)
* or be sure to use the same dbNumber when materializing a capsule.

## Environment for node
In node use one of the following to set your environment

    process.env.NODE_ENV = 'test'          // redisDB.select 9
    process.env.NODE_ENV = 'development'   // redisDB.select 8
    process.env.NODE_ENV = 'production'    // redisDB.select 7

Alternatively, you can override these defaults for the redis db when materializing a capsule:

    RedisMessageCapsule = require('redis-message-capsule')
    redisURL = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    dbNumber = 5
    capsule = RedisMessageCapsule.materializeCapsule(redisURL, dbNumber)

## Environment for ruby
In ruby use one of the following to set your environment

    ENV["RACK_ENV"] = 'test'          // redisDB.select 9
    ENV["RACK_ENV"] = 'development'   // redisDB.select 8
    ENV["RACK_ENV"] = 'production'    // redisDB.select 7

Alternatively, you can override these defaults for the redis db when materializing a capsule:

    require 'redis_message_capsule'
    redisURL = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    dbNumber = 5
    capsule = RedisMessageCapsule.materialize_capsule redisURL, dbNumber


## Build the gem locally:
    git clone git@github.com:arbind/redis_message_capsule-gem.git
    cd redis_message_capsule-gem
    bundle
    
    gem uninstall redis_message_capsule
    gem build redis_message_capsule.gemspec
    rake install


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
