# frozen_string_literal: true

module Ephem
  module Segments
    module OrientationSource
      def compute(*)
        raise UnsupportedError,
          "Use #angles_at or #orientation_at for orientation kernels"
      end

      def compute_and_differentiate(*)
        raise UnsupportedError,
          "Use #orientation_at for orientation kernels"
      end
    end
  end
end
