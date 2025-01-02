# frozen_string_literal: true

module Ephem
  module Segments
    class Registry
      def self.register(type, klass)
        SPK::SEGMENT_CLASSES[type] = klass
      end
    end
  end
end
