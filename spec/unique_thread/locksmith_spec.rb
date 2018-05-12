RSpec.describe UniqueThread::Locksmith do
  subject { described_class.new(name: name, stopwatch: stopwatch, redis: redis, logger: Logger.new('/dev/null')) }

  let(:name)      { 'the_lock' }
  let(:stopwatch) { instance_double(UniqueThread::Stopwatch) }
  let(:redis)     { Redis.new }

  before do
    redis.del(name)
    allow(stopwatch).to receive(:now).and_return(100.0)
    allow(stopwatch).to receive(:next_renewal).and_return(110.0)
  end

  describe '#new_lock' do

    it 'attempts to acquire a lock until the next milestone' do
      lock = subject.new_lock

      expect(lock).to be_acquired
    end

    it 'will not acquire the lock if it is already taken' do
      subject.new_lock # Acquires the lock

      lost_lock = subject.new_lock

      expect(lost_lock).to_not be_acquired
    end

    it 'will acquire the lock if the previous one has expired' do
      subject.new_lock # Will expire

      allow(stopwatch).to receive(:now).and_return(120.0)
      lock = subject.new_lock

      expect(lock).to be_acquired
    end

    it 'always knows the timestamp for when is the lock held until' do
      held_lock = subject.new_lock
      lost_lock = subject.new_lock

      expect(held_lock.locked_until).to eql('110.0')
      expect(lost_lock.locked_until).to eql('110.0')
    end
  end

  describe '#renew_lock' do
    it 'attempts to acquire a new lock until the next milestone' do
      lock = subject.new_lock

      allow(stopwatch).to receive(:next_renewal).and_return(120.0)
      renewed_lock = subject.renew_lock(lock)

      expect(renewed_lock).to be_acquired
      expect(renewed_lock.locked_until).to eql('120.0')
    end

    it 'might lose the lock if another process gets it' do
      lock = subject.new_lock

      allow(stopwatch).to receive(:now).and_return(120.0)
      allow(stopwatch).to receive(:next_renewal).and_return(130.0)
      subject.new_lock # "Steals" the lock

      renewed_lock = subject.renew_lock(lock)

      expect(renewed_lock).to_not be_acquired
    end
  end

  context 'held lock' do
    let(:lock) { subject.new_lock }

    before { allow(stopwatch).to receive(:sleep_until_renewal_attempt) }

    describe '#while_held' do
      it 'yields the block' do
        allow(stopwatch).to receive(:sleep_until_renewal_attempt) do
          sleep(0.1) # Allow the thread scheduler to run the block

          # "Steal" the lock to exit
          allow(stopwatch).to receive(:now).and_return(120.0)
          allow(stopwatch).to receive(:next_renewal).and_return(130.0)
          subject.new_lock
        end

        expect { |block| lock.while_held(&block) }.to yield_control
      end

      it 'keeps renewing the lock until it is lost' do
        lost_lock = instance_double(UniqueThread::Lock, acquired?: false)
        allow(subject).to receive(:renew_lock).and_return(lock, lock, lost_lock)

        lock.while_held

        expect(subject).to have_received(:renew_lock).exactly(3).times
      end

      it 'kills the block when the lock is stolen' do
        allow(stopwatch).to receive(:sleep_until_renewal_attempt) do
          sleep(0.1) # Allow the thread scheduler to run the block

          # "Steal" the lock to exit
          allow(stopwatch).to receive(:now).and_return(120.0)
          allow(stopwatch).to receive(:next_renewal).and_return(130.0)
          subject.new_lock
        end

        work_thread = nil
        lock.while_held do
          loop { work_thread = Thread.current }
        end

        expect(work_thread.pending_interrupt? || work_thread.status == false).to be(true)
      end
    end
  end

  context 'lost lock' do
    let(:lock) do
      subject.new_lock
      subject.new_lock
    end

    describe '#while_held' do
      it 'does not yield the block' do
        expect { |block| lock.while_held(&block) }.to_not yield_control
      end
    end
  end
end
