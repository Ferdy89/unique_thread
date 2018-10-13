RSpec.describe UniqueThread do
  describe '.logger' do
    let(:mock_logger) { instance_double(Logger, info: nil) }

    before { described_class.logger = nil }

    it 'defaults to the standard output' do
      expect { described_class.logger.info('Hello!') }.to output(/Hello!/).to_stdout
    end

    it 'uses the Rails logger when running on a Rails app' do
      stub_const('Rails', Class.new { def self.logger; end })
      allow(Rails).to receive(:logger).and_return(mock_logger)

      expect { described_class.logger.info('Hello!') }.to_not output.to_stdout

      expect(mock_logger).to have_received(:info).with('Hello!')
    end

    it 'does not use the Rails logger when running a Rails console' do
      stub_const('Rails', Class.new { def self.logger; end })
      allow(Rails).to receive(:logger).and_return(mock_logger)
      stub_const('Rails::Console', double) # Mimics being within a Rails console

      expect { described_class.logger.info('Hello!') }.to_not output.to_stdout

      expect(mock_logger).to_not have_received(:info)
    end

    it 'allows the user to specify their own logger' do
      described_class.logger = mock_logger

      expect { described_class.logger.info('Hello!') }.to_not output.to_stdout

      expect(mock_logger).to have_received(:info).with('Hello!')
    end
  end

  describe '.redis' do
    before { described_class.redis = nil }
    after  { described_class.redis = nil }

    it 'uses a default Redis instance' do
      expect(described_class.redis.connection[:host]).to eql('127.0.0.1')
    end

    it 'allows the user to configure their own Redis instance' do
      described_class.redis = Redis.new(host: 'localhost')

      expect(described_class.redis.connection[:host]).to eql('localhost')
    end
  end

  describe '.safe_thread' do
    it 'yields a block in a thread' do
      run = false

      described_class.safe_thread { run = true }
      sleep(0.1) # Give time for thread to run

      expect(run).to be(true)
    end

    it 'logs errors happening in the block' do
      mock_logger = instance_double(Logger, error: nil)
      described_class.logger = mock_logger

      run = true
      described_class.safe_thread do
        if run
          run = false
          raise 'Uh, oh! This is bad!'
        end
      end
      sleep(0.1) # Give time for thread to run

      expect(mock_logger).to have_received(:error).with(/Uh, oh! This is bad!/)
    end

    it 'passes errors happening in the block to any error handlers' do
      reported_errors = []
      described_class.error_handlers << ->(error) { reported_errors << error }

      run = true
      described_class.safe_thread do
        if run
          run = false
          raise 'Uh, oh! This is bad!'
        end
      end
      sleep(0.1) # Give time for thread to run

      expect(reported_errors).to contain_exactly(an_object_having_attributes(message: 'Uh, oh! This is bad!'))

      described_class.error_handlers = []
    end

    it 'continues running after an error occurs' do
      run_times = 0
      ran_again = false
      described_class.safe_thread do
        case run_times
        when 0
          run_times += 1
          raise 'Uh, oh! This is bad!'
        when 1
          run_times += 1
          ran_again = true
        end
      end
      sleep(0.1) # Give time for thread to run

      expect(ran_again).to be true
    end
  end

  describe '#run' do
    subject { described_class.new(name, downtime: 1) }

    let(:name) { 'the_lock' }

    before { Redis.new.del(name) }

    it 'only allows one thread to run at a time' do
      first_run  = false
      second_run = false

      first_thread = subject.run { first_run = true }
      sleep(0.1) # Give time for the first thread to acquire the lock
      second_thread = subject.run { second_run = true }
      sleep(0.1) # Give both threads the chance to run (if they can)

      expect(first_run).to be(true)
      expect(second_run).to be(false)

      first_thread.kill # First thread dies!
      sleep(1) # Give time for the second thread to acquire the lock (the specified downtime was 1 second)

      expect(second_run).to be(true)
      second_thread.kill
    end
  end
end
