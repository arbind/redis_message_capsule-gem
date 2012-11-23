# RedisMessageCapsule

Send messages between node or rails apps asynchronously (via redis).
* [report an issue with the ruby version] (https://github.com/arbind/redis_message_capsule/issues)
* [report an issue with the node version] (https://github.com/arbind/redis_message_capsule-node/issues)

## Installation (with npm for node) (as a gem for ruby)

    $ npm install redis_message_capsule
    $ gem install redis_message_capsule

## Usage
RedisMessageCapsule is used in the same way for both node and ruby (just the syntax is different, naturally).

The pseudo code goes something like this:

    # 1. Create a capsule that is bound to the redis DB:
    > load RedisMessageCapsule
    > capsule = materializeCapsule(redisURL, dbNumber)

    # 2. Create a named channel that you want to send or receive messages on
    > catChannel = capsule.materializeChannel('cat')

    # 3.a Either: Send messages on the channel:
    > catChannel.send('meeeooow')
    > catChannel.send('roooaaar')

    # 3.b Or: Handle the messages that are recieved on the channel:
    > messageHandler = { |message| doSomethingWith(message) }
    > catChannel.register(messageHandler) 

    # 4. Create as many channels and listeners as you want, using the capsule.

    # 5. Create as many capsules as you want (only need one capsule for each redisURL:dbNumber )

The purpose of RedisMessageCapsule is to enable separate apps to communicate with each other asynchronously.

So, normally, one app would do the sending and another would listen for the message.
However, nothing restricts the same app from doing the sending as well as receiving its own message.

## Advanced Usage
This is not your typical pub/sub model as messages are not broadcast to all apps that are listening on a channel.

If multiple apps are listening on a channel, only one will actually receive the message.
Each app can register multiple handlers for a channel, but only one app will actually get the message for processing.

In ruby, the listeners will block waiting for a message, so the app that is waiting the longest would get the message.

With node, however, there is no guarentee of order, since the listeners are not blocking the event loop.

## Demonstration
Below are code demonstrations for sending messages between 2 apps (node apps, ruby apps and a combination of both).

* Make sure redis is running
* Data or object being sent will automatically be serialized to json (in order to teleport through redis)
  * in node: using obj.toJSON() or JSON.stringify(obj)
  * in rails: using obj.to_json 
* Demo for node <-> node: Open 2 terminal windows to send messages between 2 node apps  (outlined below)
* Demo for ruby <-> ruby: Open 2 terminal windows to send messages between 2 ruby apps  (outlined below)
* Demo for node <-> ruby: Open 4 terminal windows and do both of the demos above (which are outlined below)
* Think of each window that you open as a stand-alone app

### Demo for node <-> node
In node window 1 - send cat messages:

    $ node
    RedisMessageCapsule = require('redis-message-capsule')
    redisURL = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.materializeCapsule(redisURL)
    cat = capsule.materializeChannel('cat')
    cat.send('meow')    // will show up in node window 2 (listening to cat)
    cat.send('meow')    // will show up in node window 2 (listening to cat)
 
In node window 2 - listen for cat messages, send messages from dog:

    $ node
    RedisMessageCapsule = require('redis-message-capsule')
    redisURL = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.materializeCapsule(redisURL)
    cat = capsule.materializeChannel('cat')
    cat.register( function(err, message){ console.log(message) }  ) 
    // => meow
    // => meow    
    // create a dog channel to send messages to ruby, and start barking
    dog = capsule.materializeChannel('dog')
    dog.send('woof')  // will show up in ruby window 2 (listening to dog)

In node window 1 - send more cat messages:

    talk = { say: 'roar', time: new Date() }
    cat.send(9)
    cat.send( talk )
    // Watch for real-time messages show up in node window 2:
    // => 9 
    // => {"say"=>"roar", "time"=>"2012-11-21T208:08:08.808Z"} 

###  Demo for ruby <-> ruby
In ruby window 1 - send dog messages:

    $ irb
    require 'redis_message_capsule'
    redisURL = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    capsule = RedisMessageCapsule.materialize_capsule redisURL
    dog = capsule.materialize_channel 'dog'
    dog.send 'bark'

In ruby window 2 -  listen for dog messages in ruby and send cat messages:

    $ irb
    require 'redis_message_capsule'
    redisURL = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    capsule = RedisMessageCapsule.materialize_capsule redisURL
    dog = capsule.materialize_channel 'dog'
    dog.register { |msg|  puts "#{msg}!" * 2 }
    # => woof!woof!
    # => bark!bark!
    # create a cat channel to send messages to node
    cat = capsule.materialize_channel 'cat'
    cat.send 'purrr' # will show up in node window 2 (listening to cat)

Back in ruby window 1 - send more dog messages:

    talk = { say: 'grrrrrr', time: Time.now }
    dog.send 2      # will show up in window 4 (listening to dog)
    dog.send talk   # will show up in window 4 (listening to dog)
    # Watch for real-time messages to show up in ruby window 2:
    # => 2 
    # => {"say"=>"grrrrrr", "time"=>"2012-11-21 08:08:08 -0800"} 
    # => purr

## Environment
In order for 2 apps to send messages to each other, they must bind a capsule to the same redis DB and select the same db number.

By default, RedisMessageCapsule will:
* select 9 for test environment
* select 8 for development environment
* select 7 for production environment
The selected db can also be overriden when materializing a capsule  (examples are below).

If 2 apps are not sending messages to each other:
* check that they are both in the same environment (test, development, production)
* or be sure to override using same dbNumber when materializing a capsule.

## Environment for node
In node use one of the following to set your environment

    process.env.NODE_ENV = 'test'          // redisDB.select 9
    process.env.NODE_ENV = 'development'   // redisDB.select 8 * Default
    process.env.NODE_ENV = 'production'    // redisDB.select 7

Alternatively, you can specify exactly what you want when materializing a capsule:

    RedisMessageCapsule = require('redis-message-capsule')
    redisURL = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    dbNumber = 5
    capsule = RedisMessageCapsule.materializeCapsule(redisURL, dbNumber)

## Environment for ruby
In ruby use one of the following to set your environment

    ENV["RACK_ENV"] = 'test'          // redisDB.select 9
    ENV["RACK_ENV"] = 'development'   // redisDB.select 8  * Default
    ENV["RACK_ENV"] = 'production'    // redisDB.select 7

Alternatively, you can specify exactly what you want when materializing a capsule:

    require 'redis_message_capsule'
    redisURL = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    dbNumber = 5
    capsule = RedisMessageCapsule.materialize_capsule redisURL, dbNumber

## To build the gem locally:
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
