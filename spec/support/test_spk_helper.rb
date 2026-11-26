# frozen_string_literal: true

module TestSpkHelper
  def test_spk
    File.path("#{__dir__}/data/de432s.bsp")
  end

  def de405_2000_excerpt
    File.path("#{__dir__}/data/de405_2000_excerpt.bsp")
  end

  def de421_2000_excerpt
    File.path("#{__dir__}/data/de421_2000_excerpt.bsp")
  end

  def inpop21a_2000_excerpt
    File.path("#{__dir__}/data/inpop21a_2000_excerpt.bsp")
  end

  def moon_pa_de440_excerpt
    File.path("#{__dir__}/data/moon_pa_de440_excerpt.bpc")
  end

  def moon_pa_de440_boundary_excerpt
    File.path("#{__dir__}/data/moon_pa_de440_boundary_excerpt.bpc")
  end

  def de421_2000_excerpt_with_first_target(target, directory:)
    data = File.binread(de421_2000_excerpt)
    double_count, forward_record = data.unpack("@8V@76V")
    record_size = Ephem::IO::BinaryReader::RECORD_SIZE
    control_size = Ephem::IO::RecordParser::SUMMARY_CONTROL_SIZE
    target_offset =
      (forward_record - 1) * record_size + control_size + double_count * 8
    data[target_offset, 4] = [target].pack("l<")

    path = File.join(directory, "de421_2000_excerpt_target_#{target}.bsp")
    File.binwrite(path, data)
    path
  end

  def truncated_copy(path, byte_count, directory:)
    truncated_path = File.join(directory, "truncated_#{File.basename(path)}")
    File.binwrite(truncated_path, File.binread(path, byte_count))
    truncated_path
  end
end
