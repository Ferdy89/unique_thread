# frozen_string_literal: true

require 'unique_thread'

UniqueThread.new('hello_world', downtime: 1).run do
  loop do
    puts 'Hello from the unique thread!'
    sleep(1)
  end
end

loop { sleep(1000) }
