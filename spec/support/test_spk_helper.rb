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
end
