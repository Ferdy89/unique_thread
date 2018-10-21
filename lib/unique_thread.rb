# frozen_string_literal: true

require 'logger'
require 'redis'
require_relative 'unique_thread/stopwatch'
require_relative 'unique_thread/locksmith'

class UniqueThread
  class << self
    attr_writer :logger, :redis, :error_handlers

    def logger
      @logger ||= default_logger
    end

    def redis
      @redis ||= Redis.new
    end

    def error_handlers
      @error_handlers ||= []
    end

    def safe_thread
      Thread.new do
        begin
          yield
        rescue StandardError => error
          report_error(error)
          retry
        end
      end
    end

    def run(name, &block)
      new(name).run(&block)
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

    def report_error(exception)
      logger.error(exception.inspect)
      error_handlers.each { |handler| handler.call(exception) }
    end
  end

  attr_reader :stopwatch, :locksmith

  def initialize(name, downtime: 30)
    @stopwatch = Stopwatch.new(downtime: downtime)
    @locksmith = Locksmith.new(name: name, stopwatch: stopwatch)
  end

  def run(&block)
    self.class.safe_thread do
      loop { try_being_the_unique_thread(&block) }
    end
  end

  private

  def try_being_the_unique_thread(&block)
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
