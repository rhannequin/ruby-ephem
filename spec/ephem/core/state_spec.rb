# frozen_string_literal: true

RSpec.describe Ephem::Core::State do
  describe ".new" do
    it "creates a new state with position and velocity vectors" do
      position = Ephem::Core::Vector.new(1.0, 2.0, 3.0)
      velocity = Ephem::Core::Vector.new(0.1, 0.2, 0.3)

      state = described_class.new(position, velocity)

      expect(state.position).to eq(position)
      expect(state.velocity).to eq(velocity)
    end

    it "preserves the original vectors" do
      position = Ephem::Core::Vector.new(1.0, 2.0, 3.0)
      velocity = Ephem::Core::Vector.new(0.1, 0.2, 0.3)

      state = described_class.new(position, velocity)

      expect(state.position.x).to eq(1.0)
      expect(state.position.y).to eq(2.0)
      expect(state.position.z).to eq(3.0)
      expect(state.velocity.x).to eq(0.1)
      expect(state.velocity.y).to eq(0.2)
      expect(state.velocity.z).to eq(0.3)
    end

    it "freezes the object" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])

      expect(state).to be_frozen
    end
  end

  describe ".from_arrays" do
    it "creates a state from position and velocity arrays" do
      position = [1.0, 2.0, 3.0]
      velocity = [0.1, 0.2, 0.3]

      state = described_class.from_arrays(position, velocity)

      expect(state.position.to_a).to eq(position)
      expect(state.velocity.to_a).to eq(velocity)
    end

    it "creates a state with zero position and velocity" do
      position = [0.0, 0.0, 0.0]
      velocity = [0.0, 0.0, 0.0]

      state = described_class.from_arrays(position, velocity)

      expect(state.position.to_a).to eq(position)
      expect(state.velocity.to_a).to eq(velocity)
    end

    it "handles integer arrays" do
      position = [1, 2, 3]
      velocity = [4, 5, 6]

      state = described_class.from_arrays(position, velocity)

      expect(state.position.to_a).to eq(position)
      expect(state.velocity.to_a).to eq(velocity)
    end
  end

  describe "#to_arrays" do
    it "converts state to arrays of position and velocity components" do
      position = Ephem::Core::Vector.new(1.0, 2.0, 3.0)
      velocity = Ephem::Core::Vector.new(0.1, 0.2, 0.3)
      state = described_class.new(position, velocity)

      position, velocity = state.to_arrays

      expect(position).to eq([1.0, 2.0, 3.0])
      expect(velocity).to eq([0.1, 0.2, 0.3])
    end

    it "preserves the original state after conversion" do
      position = Ephem::Core::Vector.new(1.0, 2.0, 3.0)
      velocity = Ephem::Core::Vector.new(0.1, 0.2, 0.3)
      state = described_class.new(position, velocity)

      state.to_arrays

      expect(state.position).to eq(position)
      expect(state.velocity).to eq(velocity)
    end
  end

  describe "#==" do
    it "returns true for states with equal position and velocity" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      same_state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])

      expect(state == same_state).to be(true)
    end

    it "returns false when positions differ" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      other_state = build_state([1.0, 2.0, 4.0], [0.1, 0.2, 0.3])

      expect(state == other_state).to be(false)
    end

    it "returns false when velocities differ" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      other_state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.4])

      expect(state == other_state).to be(false)
    end

    it "returns false for a non-State object" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])

      expect(state == state.to_arrays).to be(false)
      expect(state == :state).to be(false)
    end
  end

  describe "#eql?" do
    it "returns true for states with equal position and velocity" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      same_state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])

      expect(state).to eql(same_state)
    end

    it "returns false for states with different vectors" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      other_state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.4])

      expect(state).not_to eql(other_state)
    end
  end

  describe "#hash" do
    it "is equal for equal states" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      same_state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])

      expect(state.hash).to eq(same_state.hash)
    end

    it "lets equal states be used as the same hash key" do
      state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])
      same_state = build_state([1.0, 2.0, 3.0], [0.1, 0.2, 0.3])

      lookup = {state => :earth}

      expect(lookup[same_state]).to eq(:earth)
      expect([state, same_state].uniq.size).to eq(1)
    end
  end

  def build_state(position, velocity)
    described_class.from_arrays(position, velocity)
  end
end
