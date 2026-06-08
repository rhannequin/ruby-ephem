# frozen_string_literal: true

RSpec.describe Ephem::Core::Rotation do
  describe ".about_x / .about_y / .about_z" do
    it "rotates coordinates about the Z axis (passive convention)" do
      rotation = described_class.about_z(half_pi)
      rotated = described_class.apply(
        rotation,
        Ephem::Core::Vector.new(1.0, 0.0, 0.0)
      )

      expect(rotated.x).to be_within(1e-12).of(0.0)
      expect(rotated.y).to be_within(1e-12).of(-1.0)
      expect(rotated.z).to be_within(1e-12).of(0.0)
    end

    it "rotates coordinates about the X axis (passive convention)" do
      rotation = described_class.about_x(half_pi)
      rotated = described_class.apply(
        rotation,
        Ephem::Core::Vector.new(0.0, 1.0, 0.0)
      )

      expect(rotated.to_a.map { |value| value.round(12) })
        .to eq([0.0, 0.0, -1.0])
    end

    it "rotates coordinates about the Y axis (passive convention)" do
      rotation = described_class.about_y(half_pi)
      rotated = described_class.apply(
        rotation,
        Ephem::Core::Vector.new(1.0, 0.0, 0.0)
      )

      expect(rotated.to_a.map { |value| value.round(12) })
        .to eq([0.0, 0.0, 1.0])
    end

    it "returns the identity for a zero angle" do
      expect(described_class.about_z(0.0)).to eq(
        [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      )
    end
  end

  describe ".multiply" do
    it "composes rotations as standard matrix multiplication" do
      composed = described_class.multiply(
        described_class.about_z(2.5),
        described_class.about_x(0.4),
        described_class.about_z(1.2)
      )

      # An orthonormal rotation: composed * composed^T == identity
      product = described_class.multiply(composed, composed.transpose)
      identity = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      product.each_with_index do |row, row_index|
        row.each_with_index do |value, column_index|
          expect(value)
            .to be_within(1e-12).of(identity[row_index][column_index])
        end
      end
    end

    it "is associative across the supplied factors" do
      left = described_class.about_x(0.3)
      middle = described_class.about_y(0.7)
      right = described_class.about_z(1.1)

      all_at_once = described_class.multiply(left, middle, right)
      pairwise = described_class.multiply(
        described_class.multiply(left, middle), right
      )

      all_at_once.flatten.zip(pairwise.flatten).each do |combined, stepwise|
        expect(combined).to be_within(1e-12).of(stepwise)
      end
    end
  end

  describe ".apply" do
    it "returns a Core::Vector" do
      identity = described_class.about_z(0.0)
      result = described_class.apply(
        identity,
        Ephem::Core::Vector.new(4.0, 5.0, 6.0)
      )

      expect(result).to be_a(Ephem::Core::Vector)
      expect(result.to_a).to eq([4.0, 5.0, 6.0])
    end

    it "accepts a plain array as the vector" do
      identity = described_class.about_z(0.0)
      result = described_class.apply(identity, [7.0, 8.0, 9.0])

      expect(result.to_a).to eq([7.0, 8.0, 9.0])
    end
  end

  def half_pi
    Math::PI / 2
  end
end
