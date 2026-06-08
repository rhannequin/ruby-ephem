# frozen_string_literal: true

module Ephem
  module Segments
    module Registry
      TABLES = {spk: {}, pck: {}}.freeze

      def self.register(kind, type, klass)
        TABLES.fetch(kind)[type] = klass
      end

      def self.lookup(kind, type, default = nil)
        TABLES.fetch(kind).fetch(type, default)
      end
    end
  end
end
