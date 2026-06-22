# frozen_string_literal: true

module Ephem
  module Segments
    module OrientationSource
      def compute(*)
        raise NotImplementedError,
          "Use #angles_at or #orientation_at for orientation kernels"
      end

      def compute_and_differentiate(*)
        raise NotImplementedError,
          "Use #orientation_at for orientation kernels"
      end
    end
  end
end
