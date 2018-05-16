# frozen_string_literal: true

require 'logger'
require 'redis'
require_relative 'unique_thread/stopwatch'
require_relative 'unique_thread/locksmith'

class UniqueThread
  attr_reader :logger, :stopwatch, :locksmith

  def initialize(name, downtime: 30, logger: default_logger, redis: Redis.new)
    @logger    = logger
    @stopwatch = Stopwatch.new(downtime: downtime)
    @locksmith = Locksmith.new(name: name, stopwatch: stopwatch, redis: redis, logger: logger)
  end

  def run(&block)
    safe_infinite_loop do
      lock = locksmith.new_lock

      if lock.acquired?
        logger.info('Lock acquired! Running the unique thread.')
        lock.while_held(&block)
      else
        logger.debug('Could not acquire the lock. Sleeping until next attempt.')
        stopwatch.sleep_until_next_attempt(lock.locked_until.to_f)
      end
    end
  end

  private

  def self.default_logger
    case
    when defined?(Rails) && defined?(Rails::Console)
      Logger.new('/dev/null')
    when defined?(Rails)
      Rails.logger
    else
      Logger.new(STDOUT)
    end
  end

  def safe_infinite_loop
    Thread.new do
      begin
        loop { yield }
      rescue StandardError => error
        logger.error(error)
      end
    end
  end
end
