# RedisMessageCapsule

Send messages between node or rails apps asynchronously (via redis).

* [report an issue with the ruby version] (https://github.com/arbind/redis_message_capsule/issues)
* [report an issue with the node version] (https://github.com/arbind/redis_message_capsule-node/issues)

## Installation

**in node**:

    $ npm install redis_message_capsule

**in ruby**:

    $ gem install redis_message_capsule

## Usage
The purpose of RedisMessageCapsule is to enable separate apps to communicate with each other asynchronously.

The ruby implementation listens for messages in a separate thread, and node listens in a separate Fiber.

### Make sure redis is running:
The code below defaults to using redis running on localhost

### Open 2 terminal windows to simulate any mixture of ruby or node apps:
Both windows can be ruby, can be node, or one can be ruby and one can be node.

### To Send Messages From Window 1
**in node**:

    $ node
    require('redis_message_capsule')
    redisurl = 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.capsule(redisurl)
    cat = capsule.channel('cat')
    cat.send('meow')
    cat.send('meow')

**in ruby**:

    $ irb
    require('redis_message_capsule')
    redisurl = 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.capsule(redisurl)
    cat = capsule.channel('cat')
    cat.send('meow')
    cat.send('meow')

### To Receive messages In Window 2
**in node**:

    $ node
    require('redis_message_capsule')
    redisurl = 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.capsule(redisurl)
    cat = capsule.channel('cat')
    cat.register(function(err, message){ console.log(message) })

**in ruby**:

    $ irb
    require('redis_message_capsule')
    redisurl = 'redis://127.0.0.1:6379/' 
    capsule = RedisMessageCapsule.capsule(redisurl)
    cat = capsule.channel('cat')
    cat.register { |msg|  puts msg }

### To Send More Messages From Window 1
**in node**:

    cat.send(9)
    talk = { say: 'roar', time: new Date() }        // <- to create a hash in node
    cat.send( talk )

**in ruby**:

    cat.send(9)
    talk = { say: 'grrrrrr', time: Time.now }       #  <- to create a hash in ruby
    cat.send( talk )

* Use the module to create as many capsules as you want  (only need one capsule for each redisurl:redisdbnum)
* Use a capsule to create as many channels as you want   (use 'ns:channelname' to add a namespace to your channel)
* Use a channel to send as many messages as you want     (be sure the data you send can be serialized to json )
* Use a channel to register as many handlers as you want (all registered handlers on a channel will get messages)
* Send messages between any mixture of apps: [ node <-> node ] or [ ruby <-> ruby ] or [ node <-> ruby ]

## Advanced Usage
This module sends messages in a queue rather than a typical pub/sub model: messages are not broadcast to all apps.

### Multiple Listeners on a Channel Will Round Robin
* If multiple apps are listening on the same channel, only one will actually receive the message and pass it on to its registered handlers for processing.
* Listeners run in their own thread (in ruby) or fiber (in node) and may block waiting for a message.
* When a message comes in, only the app that was waiting the longest will receive it.

## Environment
In order for 2 apps to send messages to each other, they must bind a capsule to the same redis DB and select the same db number.

By default, RedisMessageCapsule will:
* select 9 for test environment
* select 8 for development environment
* select 7 for production environment
The selected db can also be overriden when materializing a capsule  (examples are below).

If 2 apps are not sending messages to each other:
* check that they are both in the same environment (test, development, production)
* or be sure to override using same redisdb when materializing a capsule.

## Environment for node
In node use one of the following to set your environment

    process.env.NODE_ENV = 'test'          // redisDB.select 9
    process.env.NODE_ENV = 'development'   // redisDB.select 8 * Default
    process.env.NODE_ENV = 'production'    // redisDB.select 7

Alternatively, you can specify exactly what you want when materializing a capsule:

    RedisMessageCapsule = require('redis_message_capsule')
    redisurl = process.env.REDIS_URL || process.env.REDISTOGO_URL || 'redis://127.0.0.1:6379/' 
    redisdb = 5
    capsule = RedisMessageCapsule.capsule(redisurl, redisdb)

## Environment for ruby
In ruby use one of the following to set your environment

    ENV["RACK_ENV"] = 'test'          // redisDB.select 9
    ENV["RACK_ENV"] = 'development'   // redisDB.select 8  * Default
    ENV["RACK_ENV"] = 'production'    // redisDB.select 7

Alternatively, you can specify exactly what you want when materializing a capsule:

    require 'redis_message_capsule'
    redisurl = ENV["REDIS_URL"] || ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/"
    redisdb = 5
    capsule = RedisMessageCapsule.capsule redisurl, redisdb

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
