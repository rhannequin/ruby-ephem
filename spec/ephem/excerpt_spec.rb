# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Ephem::Excerpt do
  include TestSpkHelper

  describe "#extract" do
    it "includes only the specified target segments" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      expect(excerpt_spk.segments.size).to eq target_ids.size
      segment_targets = excerpt_spk.segments.map(&:target)
      target_ids.each do |target_id|
        expect(segment_targets).to include(target_id)
      end

      original_spk.close
      excerpt_spk.close
    end

    it "produces a smaller file than the original" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      original_size = File.size(original_spk_path)
      excerpt_size = File.size(excerpt_path)
      expect(excerpt_size).to be < original_size

      original_spk.close
      excerpt_spk.close
    end

    it "produces identical computation results using SPK#excerpt" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)

      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "produces identical computation results using Excerpt directly" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = Ephem::Excerpt.new(original_spk).extract(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)

      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "handles a short time span correctly" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2459000.0
      end_jd = 2459001.0
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.5
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)

      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "works with a single target ID" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3]
      test_time = 2459000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      expect(excerpt_spk.segments.size).to eq 1
      expect(excerpt_spk.segments.first.target).to eq target_ids.first
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)
      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "raises an error for time outside excerpt range but works in original" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      outside_time = 2460000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]

      expect {
        excerpt_segment.compute_and_differentiate(outside_time)
      }.to raise_error(Ephem::OutOfRangeError)
      expect {
        original_segment.compute_and_differentiate(outside_time)
      }.not_to raise_error

      original_spk.close
      excerpt_spk.close
    end

    it "produces correct results for multiple test times" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_times = [
        2458849.5,
        2459000.0,
        2459215.0,
        2459580.5
      ]
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]

      test_times.each do |time|
        original_state = original_segment.compute_and_differentiate(time)
        excerpt_state = excerpt_segment.compute_and_differentiate(time)
        expect(excerpt_state.position.to_a).to eq original_state.position.to_a
        expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a
      end

      original_spk.close
      excerpt_spk.close
    end

    it "produces correct results for multiple center-target pairs" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")

      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.0
      test_pairs = [
        [0, 3],
        [0, 10],
        [3, 301],
        [3, 399]
      ]
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      test_pairs.each do |center, target|
        original_segment = original_spk[center, target]
        excerpt_segment = excerpt_spk[center, target]
        original_state = original_segment.compute_and_differentiate(test_time)
        excerpt_state = excerpt_segment.compute_and_differentiate(test_time)
        expect(excerpt_state.position.to_a).to eq original_state.position.to_a
        expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a
      end

      original_spk.close
      excerpt_spk.close
    end
  end
end
