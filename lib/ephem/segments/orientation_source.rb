# frozen_string_literal: true

module Ephem
  module Segments
    module OrientationSource
      def compute(*)
        raise UnsupportedError,
          "Use #angles_at or #orientation_at for orientation kernels"
      end
      alias_method :position_at, :compute

      def compute_and_differentiate(*)
        raise UnsupportedError,
          "Use #orientation_at for orientation kernels"
      end
      alias_method :state_at, :compute_and_differentiate
    end
  end
end
