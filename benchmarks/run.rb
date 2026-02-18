# frozen_string_literal: true

require "benchmark/ips"
require "objspace"
require_relative "../lib/ephem"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ROOT = File.expand_path("..", __dir__)
SPK_FULL = File.join(ROOT, "spec", "support", "data", "de432s.bsp")
SPK_EXCERPT = File
  .join(ROOT, "spec", "support", "data", "de421_2000_excerpt.bsp")

JD_J2000 = Ephem::Core::Constants::Time::J2000_EPOCH # 2451545.0
JD_TEST = 2459000.0 # 2020-09-30, well within de432s range

SEQUENTIAL_STEPS = 1000

# Body pairs available in DE432s: [center, target]
BODY_PAIRS = {
  "Sun" => [0, 10],
  "Earth-Moon Bary" => [0, 3],
  "Mars Bary" => [0, 4],
  "Jupiter Bary" => [0, 5],
  "Saturn Bary" => [0, 6]
}.freeze

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def separator(title)
  puts
  puts "=" * 70
  puts "  #{title}"
  puts "=" * 70
  puts
end

def ensure_file!(path)
  return if File.exist?(path)
  abort "SPK file not found: #{path}\n" \
        "Run specs first or place the file manually."
end

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

ensure_file!(SPK_FULL)
ensure_file!(SPK_EXCERPT)

puts "Ephem Benchmark Suite"
puts "-" * 70
puts "Ruby:     #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "Ephem:    #{Ephem::VERSION}"
puts "SPK:      #{File.basename(SPK_FULL)} (#{(File.size(SPK_FULL) / 1024.0 / 1024).round(2)} MB)"
puts "Excerpt:  #{File.basename(SPK_EXCERPT)} (#{(File.size(SPK_EXCERPT) / 1024.0).round(1)} KB)"
puts "J2000:    #{JD_J2000}"
puts "Test JD:  #{JD_TEST}"
puts "-" * 70

# Pre-open the main SPK file and warm up data for hot-path benchmarks
spk = Ephem::SPK.open(SPK_FULL)
segment_emb = spk[0, 3]    # Earth-Moon Barycenter
segment_sun = spk[0, 10]   # Sun

# Trigger lazy data loading so hot-path benchmarks don't include I/O
segment_emb.compute(JD_TEST)
segment_sun.compute(JD_TEST)

# Pre-compute time arrays for sequential/random benchmarks
sequential_times = Array.new(SEQUENTIAL_STEPS) { |i| JD_TEST + i }
random_times = sequential_times.shuffle

# =========================================================================
# 1. SPK FILE OPENING
# =========================================================================

separator "1. SPK File Opening"

GC.start
Benchmark.ips do |x|
  x.report("SPK.open (full 10MB)") do
    s = Ephem::SPK.open(SPK_FULL)
    s.close
  end

  x.report("SPK.open (excerpt 54KB)") do
    s = Ephem::SPK.open(SPK_EXCERPT)
    s.close
  end

  x.compare!
end

# =========================================================================
# 2. FIRST DATA LOAD (COLD START)
# =========================================================================

separator "2. First Data Load (Cold Start)"

puts "Measures the cost of the first compute() call on a segment,"
puts "which triggers lazy loading of coefficient data from disk."
puts

GC.start
Benchmark.ips do |x|
  x.report("cold compute (load + eval)") do
    segment_emb.clear_data
    segment_emb.compute(JD_TEST)
  end

  x.report("warm compute (cached)") do
    segment_emb.compute(JD_TEST)
  end

  x.compare!
end

# Ensure data is loaded again for subsequent benchmarks
segment_emb.compute(JD_TEST)

# =========================================================================
# 3. SINGLE POSITION COMPUTATION (HOT PATH)
# =========================================================================

separator "3. Single Position Computation (Hot Path)"

puts "segment.compute(time) — Chebyshev eval + Vector creation"
puts

GC.start
Benchmark.ips do |x|
  x.report("compute (position)") { segment_emb.compute(JD_TEST) }
end

# =========================================================================
# 4. SINGLE STATE COMPUTATION
# =========================================================================

separator "4. Single State Computation"

puts "segment.compute_and_differentiate(time) — position + velocity"
puts

GC.start
Benchmark.ips do |x|
  x.report("compute_and_differentiate (state)") do
    segment_emb.compute_and_differentiate(JD_TEST)
  end
end

# =========================================================================
# 5. POSITION vs STATE (COMPARISON)
# =========================================================================

separator "5. Position vs State (Direct Comparison)"

GC.start
Benchmark.ips do |x|
  x.report("compute (position only)") { segment_emb.compute(JD_TEST) }
  x.report("compute_and_differentiate") do
    segment_emb.compute_and_differentiate(JD_TEST)
  end

  x.compare!
end

# =========================================================================
# 6. SEQUENTIAL TIME ACCESS
# =========================================================================

separator "6. Sequential Time Access (#{SEQUENTIAL_STEPS} days)"

puts "Tests interval-finding binary search with temporal locality."
puts "The @last_interval cache should accelerate sequential access."
puts

GC.start
Benchmark.ips do |x|
  x.report("sequential (#{SEQUENTIAL_STEPS} days)") do
    sequential_times.each { |t| segment_emb.compute(t) }
  end
end

# =========================================================================
# 7. RANDOM TIME ACCESS
# =========================================================================

separator "7. Random Time Access (#{SEQUENTIAL_STEPS} days, shuffled)"

puts "Same times as above but shuffled — measures interval cache miss impact."
puts

GC.start
Benchmark.ips do |x|
  x.report("sequential access") do
    sequential_times.each { |t| segment_emb.compute(t) }
  end

  x.report("random access") do
    random_times.each { |t| segment_emb.compute(t) }
  end

  x.compare!
end

# =========================================================================
# 8. BATCH COMPUTATION
# =========================================================================

separator "8. Batch vs Loop Computation"

batch_sizes = [10, 100, 1000]

batch_sizes.each do |n|
  times = sequential_times.first(n)

  puts "--- Batch size: #{n} ---"
  GC.start
  Benchmark.ips do |x|
    x.report("loop (#{n} times)") do
      times.each { |t| segment_emb.compute_and_differentiate(t) }
    end

    x.report("batch (#{n} times)") do
      segment_emb.compute_and_differentiate(times)
    end

    x.compare!
  end
  puts
end

# =========================================================================
# 9. MULTIPLE BODIES
# =========================================================================

separator "9. Multiple Bodies (Computation Speed by Target)"

# Pre-load all segments
body_segments = {}
BODY_PAIRS.each do |name, (center, target)|
  seg = spk[center, target]
  seg.compute(JD_TEST) # warm up
  body_segments[name] = seg
end

GC.start
Benchmark.ips do |x|
  body_segments.each do |name, seg|
    x.report(name) { seg.compute(JD_TEST) }
  end

  x.compare!
end

# =========================================================================
# 10. CHEBYSHEV POLYNOMIAL (MICRO-BENCHMARK)
# =========================================================================

separator "10. Chebyshev Polynomial Evaluation (Micro)"

puts "Direct ChebyshevPolynomial.evaluate / evaluate_derivative calls"
puts "with real coefficients extracted from a loaded segment."
puts

# Extract real coefficient data from the loaded segment
coefficients = segment_emb.instance_variable_get(:@coefficients)
radii = segment_emb.instance_variable_get(:@radii)

# Pick the first interval's coefficients
test_coeffs = coefficients[0]
test_radius = radii[0]
test_t = 0.0 # midpoint of the interval (normalized)

puts "Polynomial degree: #{test_coeffs.size} terms"
puts "Components per term: #{test_coeffs.first.size}"
puts

GC.start
Benchmark.ips do |x|
  x.report("evaluate (position)") do
    Ephem::Computation::ChebyshevPolynomial.evaluate(test_coeffs, test_t)
  end

  x.report("evaluate_derivative (velocity)") do
    Ephem::Computation::ChebyshevPolynomial.evaluate_derivative(
      test_coeffs, test_t, test_radius
    )
  end

  x.compare!
end

# =========================================================================
# 11. VECTOR OPERATIONS
# =========================================================================

separator "11. Vector Operations"

v1 = Ephem::Core::Vector.new(1.0, 2.0, 3.0)
v2 = Ephem::Core::Vector.new(4.0, 5.0, 6.0)

GC.start
Benchmark.ips do |x|
  x.report("Vector.new") { Ephem::Core::Vector.new(1.0, 2.0, 3.0) }
  x.report("Vector + Vector") { v1 + v2 }
  x.report("Vector - Vector") { v1 - v2 }
  x.report("Vector.dot") { v1.dot(v2) }
  x.report("Vector.cross") { v1.cross(v2) }
  x.report("Vector.magnitude") { v1.magnitude }
  x.report("Vector.to_a") { v1.to_a }

  x.compare!
end

# =========================================================================
# 12. MEMORY PROFILING
# =========================================================================

separator "12. Memory Profiling"

# --- 12a. Object allocations per compute call ---
puts "--- Object allocations per call ---"
puts

# Warm up
segment_emb.compute(JD_TEST)
segment_emb.compute_and_differentiate(JD_TEST)

# Measure compute
GC.start
GC.disable
before = GC.stat[:total_allocated_objects]
segment_emb.compute(JD_TEST)
after = GC.stat[:total_allocated_objects]
GC.enable
puts "  compute (position):              #{after - before} objects allocated"

# Measure compute_and_differentiate
GC.start
GC.disable
before = GC.stat[:total_allocated_objects]
segment_emb.compute_and_differentiate(JD_TEST)
after = GC.stat[:total_allocated_objects]
GC.enable
puts "  compute_and_differentiate:       #{after - before} objects allocated"

# Measure batch of 100
times_100 = sequential_times.first(100)
GC.start
GC.disable
before = GC.stat[:total_allocated_objects]
segment_emb.compute_and_differentiate(times_100)
after = GC.stat[:total_allocated_objects]
GC.enable
alloc_100 = after - before
puts "  batch compute_and_diff (100):    #{alloc_100} objects (#{(alloc_100 / 100.0).round(1)}/call)"

puts

# --- 12b. Segment data memory footprint ---
puts "--- Segment data memory footprint ---"
puts

# Force a fresh load and measure
segment_fresh = spk[0, 3]
segment_fresh.clear_data

GC.start
before_mem = ObjectSpace.memsize_of_all
segment_fresh.compute(JD_TEST) # triggers load
GC.start
after_mem = ObjectSpace.memsize_of_all

delta_kb = (after_mem - before_mem) / 1024.0
puts "  Segment [0,3] data load:         ~#{delta_kb.round(1)} KB"

# Report coefficient array size
coeffs = segment_fresh.instance_variable_get(:@coefficients)
if coeffs
  puts "  Coefficient records:             #{coeffs.size}"
  puts "  Terms per record:                #{coeffs.first&.size}"
  puts "  Components per term:             #{coeffs.first&.first&.size}"
end

# =========================================================================
# Cleanup
# =========================================================================

spk.close

separator "Benchmark Complete"
