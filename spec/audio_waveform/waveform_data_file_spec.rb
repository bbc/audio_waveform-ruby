require 'spec_helper'

require 'tempfile'
require 'tmpdir'

describe AudioWaveform::WaveformDataFile do
  context "with valid 8-bit data file" do
    let(:filename) { "spec/data/test_file_stereo_8bit_64spp.dat" }
    let(:file) { AudioWaveform::WaveformDataFile.new(filename: filename) }

    describe "to_binary" do
      it "should return binary data" do
        output = file.to_binary

        output.bytesize.should == 3620

        expected = Digest::MD5.hexdigest(File.read(filename))
        actual   = Digest::MD5.hexdigest(output)

        actual.should == expected

        fields = output.unpack("lLllL")
        fields[0].should == 1 # version
        fields[1].should == 1 # flags (8-bit)
        fields[2].should == 16000
        fields[3].should == 64
        fields[4].should == 1800
      end
    end

    describe "save_as_binary" do
      let(:temp_filename) {
        File.join(Dir.tmpdir, Dir::Tmpname.make_tmpname("waveform", 1))
      }

      after do
        File.unlink(temp_filename)
      end

      it "should write binary data to a file" do
        result = file.save_as_binary(temp_filename)
        result.should == file

        data = File.open(temp_filename, "rb") { |f| f.read }

        data.bytesize.should == 3620
      end
    end

    describe "to_json" do
      it "should return JSON data" do
        output = file.to_json

        data = JSON.parse(output)

        data.should have_key("sample_rate")
        data["sample_rate"].should == 16000

        data.should have_key("samples_per_pixel")
        data["samples_per_pixel"].should == 64

        data.should have_key("bits")
        data["bits"].should == 8

        data.should have_key("length")
        data["length"].should == 1800

        data.should have_key("data")
        data["data"].should be_instance_of(Array)
        data["data"].size.should == 3600
      end
    end

    describe "save_as_json" do
      let(:temp_filename) {
        File.join(Dir.tmpdir, Dir::Tmpname.make_tmpname("waveform", 1))
      }

      after do
        File.unlink(temp_filename)
      end

      it "should write JSON data to a file" do
        result = file.save_as_json(temp_filename)
        result.should == file

        data = File.open(temp_filename, "rb") { |f| f.read }

        obj = JSON.parse(data)
        obj.should have_key("sample_rate")
        obj.should have_key("samples_per_pixel")
        obj.should have_key("bits")
        obj.should have_key("length")
        obj.should have_key("data")
      end
    end

    describe "attributes" do
      it "should return sample rate in hertz" do
        file.sample_rate.should == 16000
      end

      it "should return samples per pixel" do
        file.samples_per_pixel.should == 64
      end

      it "should return waveform data resolution in bits" do
        file.bits.should == 8
      end

      it "should not have a start time" do
        file.start_time.should be_nil
      end

      it "should return number of min and max waveform data pairs" do
        file.size.should == 1800
      end

      it "should return waveform data" do
        file.min_sample(0).should == 0
        file.max_sample(0).should == 0

        file.min_sample(26).should == -53
        file.max_sample(26).should == 64

        file.min_sample(206).should == 8
        file.max_sample(206).should == 17

        file.min_sample(217).should == -15
        file.max_sample(217).should == -1

        file.min_sample(1799).should == 0
        file.max_sample(1799).should == 0
      end
    end
  end

  context "with valid 16-bit data file" do
    let(:filename) { "spec/data/test_file_stereo_16bit_64spp.dat" }
    let(:file) { AudioWaveform::WaveformDataFile.new(filename: filename) }

    describe "attributes" do
      it "should return sample rate in hertz" do
        file.sample_rate.should == 16000
      end

      it "should return samples per pixel" do
        file.samples_per_pixel.should == 64
      end

      it "should return waveform data resolution in bits" do
        file.bits.should == 16
      end

      it "should not have a start time" do
        file.start_time.should be_nil
      end

      it "should return number of min and max waveform data pairs" do
        file.size.should == 1800
      end

      it "should return waveform data" do
        file.min_sample(0).should == 0
        file.max_sample(0).should == 0

        file.min_sample(26).should == -13606
        file.max_sample(26).should == 16602

        file.min_sample(206).should == 2166
        file.max_sample(206).should == 4512

        file.min_sample(217).should == -4052
        file.max_sample(217).should == -430

        file.min_sample(1799).should == -8
        file.max_sample(1799).should == 7
      end
    end
  end

  context "with a file containing no waveform data" do
    let(:filename) { "spec/data/zero_length.dat" }
    let(:file) { AudioWaveform::WaveformDataFile.new(filename: filename) }

    describe "attributes" do
      it "should return sample rate in hertz" do
        file.sample_rate.should == 16000
      end

      it "should return samples per pixel" do
        file.samples_per_pixel.should == 64
      end

      it "should return waveform data resolution in bits" do
        file.bits.should == 8
      end

      it "should not have a start time" do
        file.start_time.should be_nil
      end

      it "should return number of min and max waveform data pairs" do
        file.size.should == 0
      end
    end
  end

  context "with a version 2 data file" do
    let(:filename) { "spec/data/version2.dat" }

    it "should not load the file" do
      expect {
        AudioWaveform::WaveformDataFile.new(filename: filename)
      }.to raise_error(AudioWaveform::Error, "Cannot load data file version: 2")
    end
  end

  context "with a file with invalid scale" do
    let(:filename) { "spec/data/scale_too_low.dat" }

    it "should not load the file" do
      expect {
        AudioWaveform::WaveformDataFile.new(filename: filename)
      }.to raise_error(AudioWaveform::Error, "Invalid samples per pixel: 0")
    end
  end

  context "with a file with invalid sample rate" do
    let(:filename) { "spec/data/sample_rate_too_low.dat" }

    it "should not load the file" do
      expect {
        AudioWaveform::WaveformDataFile.new(filename: filename)
      }.to raise_error(AudioWaveform::Error, "Invalid sample rate: 0")
    end
  end

  context "with a file with incomplete header" do
    let(:filename) { "spec/data/invalid_header.dat" }

    it "should not load the file" do
      expect {
        AudioWaveform::WaveformDataFile.new(filename: filename)
      }.to raise_error(AudioWaveform::Error, "Failed to read file header")
    end
  end

  context "with a newly created waveform data file" do
    let(:file) {
      AudioWaveform::WaveformDataFile.new(
        sample_rate: 44100,
        samples_per_pixel: 512,
        bits: 16
      )
    }

    describe "append" do
      it "should append waveform data points" do
        file.size.should == 0

        file.append(-99, 101).append(-49, 51)

        file.size.should == 2
        file.min_sample(0).should == -99
        file.max_sample(0).should == 101
        file.min_sample(1).should == -49
        file.max_sample(1).should == 51
      end
    end

    describe "to_binary" do
      it "should return binary data" do
        output = file.to_binary

        output.bytesize.should == 20

        fields = output.unpack("lLllL")
        fields[0].should == 1 # version
        fields[1].should == 0 # flags (16-bit)
        fields[2].should == 44100
        fields[3].should == 512
        fields[4].should == 0
      end
    end

    describe "to_json" do
      it "should return JSON string" do
        output = file.to_json

        data = JSON.parse(output)

        data.should have_key("sample_rate")
        data["sample_rate"].should == 44100

        data.should have_key("samples_per_pixel")
        data["samples_per_pixel"].should == 512

        data.should have_key("bits")
        data["bits"].should == 16

        data.should have_key("length")
        data["length"].should == 0

        data.should have_key("data")
        data["data"].should be_instance_of(Array)
        data["data"].size.should == 0

        data.should_not have_key("start_time")
      end
    end
  end

  context "with new waveform data file with start time" do
    let(:file) {
      AudioWaveform::WaveformDataFile.new(
        sample_rate: 44100,
        samples_per_pixel: 512,
        bits: 16,
        start_time: 8.5
      )
    }

    describe "attributes" do
      it "should return start time" do
        file.start_time.should == 8.5
      end
    end

    describe "to_json" do
      it "should include start_time field in output" do
        output = file.to_json

        data = JSON.parse(output)

        data.should have_key("start_time")
        data["start_time"].should == 8.5
      end
    end

  end

  context "invalid constructor arguments" do
    describe "bits" do
      it "should raise exception if not 8 or 16" do
        expect {
          AudioWaveform::WaveformDataFile.new(
            sample_rate: 44100,
            samples_per_pixel: 512,
            bits: 10
          )
        }.to raise_error(AudioWaveform::Error, %r{Invalid bits})
      end
    end

    describe "sample_rate" do
      it "should raise exception if too small" do
        expect {
          AudioWaveform::WaveformDataFile.new(
            sample_rate: 0,
            samples_per_pixel: 512,
            bits: 8
          )
        }.to raise_error(AudioWaveform::Error, %r{Invalid sample rate})
      end
    end

    describe "samples_per_pixel" do
      it "should raise exception if too small" do
        expect {
          AudioWaveform::WaveformDataFile.new(
            sample_rate: 44100,
            samples_per_pixel: 0,
            bits: 8
          )
        }.to raise_error(AudioWaveform::Error, %r{Invalid samples per pixel})
      end
    end

    describe "start_time" do
      it "should raise exception if less than zero" do
        expect {
          AudioWaveform::WaveformDataFile.new(
            sample_rate: 44100,
            samples_per_pixel: 512,
            bits: 8,
            start_time: -1.0
          )
        }.to raise_error(AudioWaveform::Error, %r{Invalid start time})
      end
    end
  end
end
