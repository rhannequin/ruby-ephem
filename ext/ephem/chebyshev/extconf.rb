# frozen_string_literal: true

require "mkmf"

# Disable FMA (fused multiply-add) contraction so that the C extension
# produces bit-identical results to the pure-Ruby implementation.
# Without this, ARM64 compilers emit fmadd instructions that skip
# intermediate rounding, causing ULP-level differences.
append_cflags("-ffp-contract=off")

create_makefile("ephem/chebyshev")
