# frozen_string_literal: true

module Ephem
  module Core
    class Vector
      attr_reader :x, :y, :z

      def initialize(x, y, z)
        unless x.is_a?(Numeric) && y.is_a?(Numeric) && z.is_a?(Numeric)
          raise ArgumentError, "Vector components must be numeric"
        end

        @x = x
        @y = y
        @z = z
      end

      def self.[](x, y, z)
        new(x, y, z)
      end

      def +(other)
        self.class.new(x + other.x, y + other.y, z + other.z)
      end

      def -(other)
        self.class.new(x - other.x, y - other.y, z - other.z)
      end

      def *(other)
        self.class.new(x * other, y * other, z * other)
      end

      def /(other)
        self.class.new(x / other, y / other, z / other)
      end

      def dot(other)
        x * other.x + y * other.y + z * other.z
      end

      def cross(other)
        self.class.new(
          y * other.z - z * other.y,
          z * other.x - x * other.z,
          x * other.y - y * other.x
        )
      end

      def magnitude
        Math.sqrt(x * x + y * y + z * z)
      end

      def to_a
        [x, y, z]
      end

      def inspect
        "Vector[#{x}, #{y}, #{z}]"
      end
      alias_method :to_s, :inspect

      # Array-like access for compatibility
      def [](index)
        case index
        when 0 then x
        when 1 then y
        when 2 then z
        else raise IndexError, "Invalid index: #{index}"
        end
      end
    end
  end
end
