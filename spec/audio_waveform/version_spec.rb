require 'spec_helper'

describe AudioWaveform do
  describe "version" do
    it "should return version number" do
      expect(AudioWaveform::VERSION).to match %r{^(\d+)(\.(\d+)){2}$}
    end
  end
end
