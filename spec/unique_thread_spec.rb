RSpec.describe UniqueThread do
  subject { described_class.new(name, downtime: 1, logger: Logger.new('/dev/null')) }

  let(:name) { 'the_lock' }

  before { Redis.new.del(name) }

  describe '#run' do
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
