# RedisMessageCapsule

Send and receive real-time messages between applications (via redis).

## Installation

Add this line to your application's Gemfile:

    gem 'redis_message_capsule'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis_message_capsule

## Usage

Open terminal window one:

    $ irb
    > require 'redis_message_capsule'
    > channel_cat = RedisMessageCapsule.channel('cat')
    > channel_cat.send('meow')

Open terminal window two:

    $ irb
    > require 'redis_message_capsule'
    > RedisMessageCapsule.listen('cat') do |msg| 
    >     puts msg
    > end
    => meow

Go back to terminal window one:

    > channel_cat.send 100
    > channel_cat.send say: 'roar', time: Time.now
    > channel_cat.send :purr

Watch for messages in terminal window two:

    => 100 
    => {"say"=>"roar", "time"=>"2012-11-19 23:16:08 -0800"} 
    => purr

(Make sure you have redis running)

## Comming Soon

A node.js version you can use to send messages back and forth between node and rails apps.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
