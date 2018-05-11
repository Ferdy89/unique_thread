# frozen_string_literal: true

class UniqueThread
  class Stopwatch
    attr_reader :downtime

    def initialize(downtime:)
      @downtime = downtime.to_f
    end

    def now
      Time.now.to_f
    end

    def next_renewal
      now + (downtime * 2 / 3)
    end

    def sleep_until_next_attempt(locked_until)
      seconds_until_next_attempt = [locked_until - now + Random.new.rand(downtime / 3), 0].max

      Kernel.sleep(seconds_until_next_attempt)
    end

    def sleep_until_renewal_attempt
      Kernel.sleep(downtime / 3)
    end
  end
end
