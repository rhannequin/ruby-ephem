# frozen_string_literal: true

module Ephem
  module Core
    # A three-dimensional vector class designed for astronomical calculations.
    # This class provides basic vector operations and is optimized for celestial
    # mechanics and astronomical coordinate transformations.
    #
    # @example Create a vector representing a position in space
    #   position = Ephem::Vector.new(1.0, 2.0, 3.0)
    #
    # @example Calculate the cross product of two vectors
    #   pos = Ephem::Vector.new(1.0, 0.0, 0.0)
    #   vel = Ephem::Vector.new(0.0, 1.0, 0.0)
    #   angular_momentum = pos.cross(vel)
    class Vector
      # @return [Numeric] x component of the vector
      attr_reader :x

      # @return [Numeric] y component of the vector
      attr_reader :y

      # @return [Numeric] z component of the vector
      attr_reader :z

      # Creates a new Vector instance.
      #
      # @param x [Numeric] The x component of the vector
      # @param y [Numeric] The y component of the vector
      # @param z [Numeric] The z component of the vector
      #
      # @raise [Ephem::InvalidInputError] if any component is not numeric
      #
      # @example Create a vector at the origin
      #   vector = Ephem::Vector.new(0, 0, 0)
      def initialize(x, y, z)
        unless x.is_a?(Numeric) && y.is_a?(Numeric) && z.is_a?(Numeric)
          raise InvalidInputError, "Vector components must be numeric"
        end

        @x = x
        @y = y
        @z = z
        freeze
      end

      # Alternative constructor for creating vectors.
      #
      # @param x [Numeric] The x component of the vector
      # @param y [Numeric] The y component of the vector
      # @param z [Numeric] The z component of the vector
      #
      # @return [Ephem::Vector] A new vector instance
      #
      # @example Create a vector using square bracket notation
      #   vector = Ephem::Vector[1, 2, 3]
      def self.[](x, y, z)
        new(x, y, z)
      end

      # Adds two vectors.
      #
      # @param other [Ephem::Vector] The vector to add
      #
      # @return [Ephem::Vector] A new vector representing the sum
      #
      # @example Add two position vectors
      #   sum = vector1 + vector2
      def +(other)
        self.class.new(x + other.x, y + other.y, z + other.z)
      end

      # Subtracts two vectors.
      #
      # @param other [Ephem::Vector] The vector to subtract
      #
      # @return [Ephem::Vector] A new vector representing the difference
      #
      # @example Calculate relative position
      #   relative_position = position1 - position2
      def -(other)
        self.class.new(x - other.x, y - other.y, z - other.z)
      end

      # Calculates the dot product with another vector.
      #
      # @param other [Ephem::Vector] The vector to calculate dot product with
      #
      # @return [Numeric] The dot product of the two vectors
      #
      # @example Calculate work done (force · displacement)
      #   work = force.dot(displacement)
      def dot(other)
        x * other.x + y * other.y + z * other.z
      end

      # Calculates the cross product with another vector.
      #
      # @param other [Ephem::Vector] The vector to calculate cross product with
      #
      # @return [Ephem::Vector] A new vector representing the cross product
      #
      # @example Calculate angular momentum (position × velocity)
      #   angular_momentum = position.cross(velocity)
      def cross(other)
        self.class.new(
          y * other.z - z * other.y,
          z * other.x - x * other.z,
          x * other.y - y * other.x
        )
      end

      # Calculates the magnitude (length) of the vector.
      #
      # @return [Numeric] The magnitude of the vector
      #
      # @example Calculate distance from origin
      #   distance = vector.magnitude
      def magnitude
        Math.sqrt(x * x + y * y + z * z)
      end
      alias_method :length, :magnitude
      alias_method :norm, :magnitude

      # Converts the vector to an array.
      #
      # @return [Array<Numeric>] Array containing [x, y, z] components
      #
      # @example Get vector components as array
      #   coordinates = vector.to_a
      def to_a
        [x, y, z]
      end

      # Returns a string representation of the vector.
      #
      # @return [String] String representation in format "Vector[x, y, z]"
      def inspect
        "Vector[#{x}, #{y}, #{z}]"
      end
      alias_method :to_s, :inspect

      # Provides array-like access to vector components.
      #
      # @param index [Integer] Index of the component
      #   (0 for x, 1 for y, 2 for z)
      #
      # @return [Numeric] The value of the component at the specified index
      #
      # @raise [IndexError] if index is not 0, 1, or 2
      #
      # @example Access z component
      #   z_value = vector[2]
      def [](index)
        case index
        when 0 then x
        when 1 then y
        when 2 then z
        else raise IndexError, "Invalid index: #{index}"
        end
      end

      # Generates a hash value for the vector.
      #
      # @return [Integer] Hash value based on vector components and class
      def hash
        [x, y, z, self.class].hash
      end

      # Checks equality with another vector.
      #
      # @param other [Ephem::Vector] The vector to compare with
      #
      # @return [Boolean] true if vectors are equal, false otherwise
      #
      # @raise [InvalidInputError] if comparing with non-Vector object
      #
      # @example Check if two vectors are equal
      #   vector1 == vector2
      def ==(other)
        unless other.is_a?(self.class)
          raise InvalidInputError, "Can only compare with another Vector"
        end

        [x, y, z] == [other.x, other.y, other.z]
      end
      alias_method :eql?, :==
    end
  end
end
