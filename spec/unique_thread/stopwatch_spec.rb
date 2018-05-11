RSpec.describe UniqueThread::Stopwatch do
  subject { described_class.new(downtime: 60) }

  let(:current_time) { Time.new(2018, 5, 11, 13, 30, 11.050) }

  before { allow(Time).to receive(:now).and_return(current_time) }

  describe '#now' do
    it 'gives the current time in epoch with decimals' do
      expect(subject.now).to eql(1_526_063_411.05)
    end
  end

  describe '#next_renewal' do
    it 'points to two thirds of the allowed downtime from now' do
      expect(subject.next_renewal).to eql(1_526_063_451.05)
    end
  end

  describe '#sleep_until_next_attempt' do
    it 'sleeps until the lock presumably expires (with an extra random amount up to a third of the downtime)' do
      allow(Kernel).to receive(:sleep)
      next_attempt = Time.new(2018, 5, 11, 13, 30, 51.050).to_f

      subject.sleep_until_next_attempt(next_attempt)

      expect(Kernel).to have_received(:sleep) do |wait|
        expect(wait).to be_within(10).of(50)
      end
    end

    it 'does not sleep when the next attempt has already passed' do
      allow(Kernel).to receive(:sleep)
      next_attempt = Time.new(2018, 5, 11, 13, 29).to_f

      subject.sleep_until_next_attempt(next_attempt)

      expect(Kernel).to have_received(:sleep).with(0)
    end
  end

  describe '#sleep_until_renewal_attempt' do
    it 'sleeps for a third of the downtime' do
      allow(Kernel).to receive(:sleep)

      subject.sleep_until_renewal_attempt

      expect(Kernel).to have_received(:sleep).with(20)
    end
  end
end
