# setup for test environment
ENV['RACK_ENV'] = 'test'

# set up test coverage
require 'simplecov'
SimpleCov.start do
  minimum_coverage 100
end

require 'RedisMessageCapsule'

# Dont let tests overwrite any production or development data
abort('Redis not configured for test environment !!!')    unless REDIS_DB.eql? REDIS_DB_ENVIRONMENTS[:test]
