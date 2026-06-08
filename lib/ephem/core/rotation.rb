# frozen_string_literal: true

module Ephem
  module Core
    # Builds and applies 3x3 rotation matrices. Kernel-agnostic: callers choose
    # the axis sequence and order that matches their frame convention.
    #
    # The elementary rotations use the coordinate-frame (passive) convention:
    # they express a fixed vector in a frame rotated by +angle about the axis
    module Rotation
      # @param angle [Numeric] rotation angle in radians
      # @return [Array<Array<Float>>] rotation about the X axis
      def self.about_x(angle)
        cosine = Math.cos(angle)
        sine = Math.sin(angle)
        [
          [1.0, 0.0, 0.0],
          [0.0, cosine, sine],
          [0.0, -sine, cosine]
        ]
      end

      # @param angle [Numeric] rotation angle in radians
      # @return [Array<Array<Float>>] rotation about the Y axis
      def self.about_y(angle)
        cosine = Math.cos(angle)
        sine = Math.sin(angle)
        [
          [cosine, 0.0, -sine],
          [0.0, 1.0, 0.0],
          [sine, 0.0, cosine]
        ]
      end

      # @param angle [Numeric] rotation angle in radians
      # @return [Array<Array<Float>>] rotation about the Z axis
      def self.about_z(angle)
        cosine = Math.cos(angle)
        sine = Math.sin(angle)
        [
          [cosine, sine, 0.0],
          [-sine, cosine, 0.0],
          [0.0, 0.0, 1.0]
        ]
      end

      # Product of rotation matrices in the given order, as standard matrix
      # multiplication: +multiply(a, b, c)+ returns +a * b * c+.
      #
      # @param matrices [Array<Array<Array<Float>>>] one or more 3x3 matrices
      # @return [Array<Array<Float>>] the combined rotation matrix
      def self.multiply(*matrices)
        matrices.reduce { |product, matrix| multiply_pair(product, matrix) }
      end

      # Applies a rotation matrix to a vector.
      #
      # @param matrix [Array<Array<Float>>] a 3x3 rotation matrix
      # @param vector [Core::Vector, Array<Numeric>] the vector to rotate
      # @return [Core::Vector] the rotated vector
      def self.apply(matrix, vector)
        x, y, z = vector.to_a
        Vector.new(
          matrix[0][0] * x + matrix[0][1] * y + matrix[0][2] * z,
          matrix[1][0] * x + matrix[1][1] * y + matrix[1][2] * z,
          matrix[2][0] * x + matrix[2][1] * y + matrix[2][2] * z
        )
      end

      def self.multiply_pair(left, right)
        Array.new(3) do |row|
          Array.new(3) do |column|
            left[row][0] * right[0][column] +
              left[row][1] * right[1][column] +
              left[row][2] * right[2][column]
          end
        end
      end
      private_class_method :multiply_pair
    end
  end
end
