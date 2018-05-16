# frozen_string_literal: true

class UniqueThread
  class Locksmith
    attr_reader :name, :stopwatch

    def initialize(name:, stopwatch:)
      @name      = name
      @stopwatch = stopwatch

      @lua_scripts = Hash[Dir[File.join(__dir__, 'redis_lua', '*.lua')].map do |lua_file|
        [File.basename(lua_file, '.lua').to_sym, UniqueThread.redis.script(:load, File.read(lua_file))]
      end]
    end

    def new_lock
      lock_from_redis_command(:get_lock, name, stopwatch.now, stopwatch.next_renewal)
    end

    def renew_lock(lock)
      lock_from_redis_command(:extend_lock, name, lock.locked_until, stopwatch.next_renewal)
    end

    private

    RedisResult = Struct.new(:lock_acquired, :locked_until) do
      def lock_acquired?
        lock_acquired == '1'
      end
    end

    attr_reader :lua_scripts

    def lock_from_redis_command(script, *args)
      redis_result = RedisResult.new(*UniqueThread.redis.evalsha(lua_scripts[script], args))

      klass = if redis_result.lock_acquired?
                HeldLock
              else
                Lock
              end

      klass.new(redis_result.locked_until, stopwatch, self)
    end
  end

  private

  class Lock
    attr_reader :locked_until, :stopwatch, :locksmith

    def initialize(locked_until, stopwatch, locksmith)
      @locked_until = locked_until
      @stopwatch    = stopwatch
      @locksmith    = locksmith
    end

    def acquired?
      false
    end

    def while_held
      nil
    end
  end

  class HeldLock < Lock
    def acquired?
      true
    end

    def while_held
      worker = Thread.new do
        yield
        UniqueThread.logger.error('The blocked passed is not an infinite loop.')
      end

      renew_indefinitely

      UniqueThread.logger.info('Lock lost! Killing the unique thread.')
      worker.terminate
    end

    private

    def renew_indefinitely
      active_lock = self

      while active_lock.acquired?
        UniqueThread.logger.debug('Lock renewed! Sleeping until next renewal attempt.')
        stopwatch.sleep_until_renewal_attempt
        active_lock = locksmith.renew_lock(active_lock)
      end
    end
  end
end
