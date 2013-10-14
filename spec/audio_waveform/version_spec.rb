require 'spec_helper'

describe AudioWaveform do
  describe "version" do
    it "should return version number" do
      AudioWaveform::VERSION.should match %r{^(\d+)(\.(\d+)){2}$}
    end
  end
end
