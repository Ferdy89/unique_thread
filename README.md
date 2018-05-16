# Unique Thread [![Build Status](https://travis-ci.org/Ferdy89/unique_thread.svg?branch=master)](https://travis-ci.org/Ferdy89/unique_thread)

Allows multiple processes to coordinate to make sure one of them (and only one
of them) is running a block of code at all times.

```ruby
UniqueThread.new('my_lock').run do
  loop do
    puts 'Hello from the unique thread!'
    sleep(10)
  end
end
```

Even if multiple processes run the code above simultaneously, only one will run
the block (as long as they're all connected to the same Redis instance). Even
if the process that was running the code goes down unexpectedly, another one
will pick up the work immediately.

## Use cases

### Running a cron scheduler

If you have a Ruby implementation of a cron scheduler in your app, you probably
don't want to neither schedule your jobs multiple times nor have to have a
separate process exclusively running your scheduler. Instead, you can have your
cron scheduler run inside of a Unique Thread and you won't have to deploy a
separate process nor you will schedule jobs multiple times!

### Reporting statistics from your app

Say you wanted to report the number of active orders of your e-commerce site
every minute to an external site where you're analyzing that data. Once again,
you don't want to report the information more than once a minute and you also
don't want to deploy a separate process for this. Use a Unique Thread and be
happy!

### Regularly pull external data into your database

Reverting the previous example, imagine you wanted to update your local cache
to reflect the latest data from a third party API. You don't want to be
throttled, so you don't want all of your processes querying the API. Using a
Unique Thread will make it very simple to update your cache with whatever
frequency you need.

## Configure your Unique Thread

These are the full options you can pass to your Unique Thread

```ruby
UniqueThread.new('name', downtime: 30, logger: Logger.new(STDOUT), redis: Redis.new)
```

### Redis

Unique Thread will use the default connection parameters for Redis, which means
it'll try to connect to `ENV['REDIS_URL']` or to `localhost`. However, you can
pass your own Redis instance to your Unique Thread if you need finer tuning.

### Logger

Unique Thread will try to use the Rails logger when running on a Rails app.
However, it will disable logging when running a `rails console` to avoid noise
in the console. When used outside Rails, it'll log to standard output by
default but you can pass in your own logger to have finer tuning.

### Downtime

The concept of downtime represents the maximum amount of time allowed without a
Unique Thread running. Because any process might go down at any point without
previous notice, Unique Thread will have all the processes regularly polling
Redis to battle to become "the one". It's impossible to guarantee that there
will always be a process running the Unique Thread. Instead, you can configure
your tolerance for downtime. For a cron scheduler, for example, you might need
it to run every minute, so your tolerance for downtime could be anything below
60 seconds. Keep in mind that a lower downtime means that the processes will
have to poll Redis more often, which might have performance implications if you
share your database for other purposes.

## Reliability

As of right now, Unique Thread hasn't been tested on a production application
with real workload.

Besides, Unique Thread is meant to work with a single master Redis instance
with no replication. If you have a complicated Redis network, you might need to
look into more advanced alternatives.

Finally, Unique Thread hasn't been tested for a downtime lower than 1 second.
Once again, if your application requires higher uptime for your Unique Thread,
then you might want to look into other alternatives.

## Try for yourself

To run the example included with this repository, run the following steps:

1. Clone the repository
1. Run `bundle install`
1. Start a local Redis server locally
1. Run two (or more) separate processes with

```bash
bundle exec ruby examples/init.rb
```

You will see a lot of log statements in your screen explaining what's going on.
One of the processes should be printing a greeting message and keep renewing
the lock, while the rest should keep waiting to acquire the lock.

The example has an allowed downtime of 1 second, which means the thread should
react very quickly to changes from each other. Now press Ctrl+C on the process
that's printing the greeting message and watch how another process will take
over and start printing the message.

The result is that as long as there's one process running the code, the message
will always be printed somewhere. Also, only one process will be printing the
message at a time.
