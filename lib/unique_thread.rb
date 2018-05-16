# frozen_string_literal: true

require 'logger'
require 'redis'
require_relative 'unique_thread/stopwatch'
require_relative 'unique_thread/locksmith'

class UniqueThread
  class << self
    attr_writer :logger, :redis

    def logger
      @logger ||= default_logger
    end

    def redis
      @redis ||= Redis.new
    end

    private

    def default_logger
      case
      when defined?(Rails) && defined?(Rails::Console)
        Logger.new('/dev/null')
      when defined?(Rails)
        Rails.logger
      else
        Logger.new($stdout)
      end
    end
  end

  attr_reader :stopwatch, :locksmith

  def initialize(name, downtime: 30)
    @stopwatch = Stopwatch.new(downtime: downtime)
    @locksmith = Locksmith.new(name: name, stopwatch: stopwatch)
  end

  def run(&block)
    safe_infinite_loop do
      lock = locksmith.new_lock

      if lock.acquired?
        self.class.logger.info('Lock acquired! Running the unique thread.')
        lock.while_held(&block)
      else
        self.class.logger.debug('Could not acquire the lock. Sleeping until next attempt.')
        stopwatch.sleep_until_next_attempt(lock.locked_until.to_f)
      end
    end
  end

  private

  def safe_infinite_loop
    Thread.new do
      begin
        loop { yield }
      rescue StandardError => error
        self.class.logger.error(error)
      end
    end
  end
end
