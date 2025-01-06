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
end
