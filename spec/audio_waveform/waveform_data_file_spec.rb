require 'spec_helper'

require 'digest'
require 'tempfile'

def get_temp_filename(prefix)
  temp_file = Tempfile.new(prefix)
  path = temp_file.path
  temp_file.unlink
  path
end

describe AudioWaveform::WaveformDataFile do
  context "with valid 8-bit data file" do
    let(:filename) { "spec/data/test_file_stereo_8bit_64spp.dat" }
    let(:file) { AudioWaveform::WaveformDataFile.new(filename: filename) }

    describe "to_binary" do
      it "should return binary data" do
        output = file.to_binary

        expect(output.bytesize).to eq(3620)

        expected = Digest::MD5.hexdigest(File.read(filename))
        actual   = Digest::MD5.hexdigest(output)

        expect(actual).to eq(expected)

        fields = output.unpack("lLllL")
        expect(fields[0]).to eq(1) # version
        expect(fields[1]).to eq(1) # flags (8-bit)
        expect(fields[2]).to eq(16000)
        expect(fields[3]).to eq(64)
        expect(fields[4]).to eq(1800)
      end
    end

    describe "save_as_binary" do
      let(:temp_filename) {
        get_temp_filename('waveform')
      }

      after do
        File.unlink(temp_filename)
      end

      it "should write binary data to a file" do
        result = file.save_as_binary(temp_filename)
        expect(result).to eq(file)

        data = File.open(temp_filename, "rb") { |f| f.read }

        expect(data.bytesize).to eq(3620)
      end
    end

    describe "to_json" do
      it "should return JSON data" do
        output = file.to_json

        data = JSON.parse(output)

        expect(data).to have_key("sample_rate")
        expect(data["sample_rate"]).to eq(16000)

        expect(data).to have_key("samples_per_pixel")
        expect(data["samples_per_pixel"]).to eq(64)

        expect(data).to have_key("bits")
        expect(data["bits"]).to eq(8)

        expect(data).to have_key("length")
        expect(data["length"]).to eq(1800)

        expect(data).to have_key("data")
        expect(data["data"]).to be_instance_of(Array)
        expect(data["data"].size).to eq(3600)
      end
    end

    describe "save_as_json" do
      let(:temp_filename) {
        get_temp_filename('waveform')
      }

      after do
        File.unlink(temp_filename)
      end

      it "should write JSON data to a file" do
        result = file.save_as_json(temp_filename)
        expect(result).to eq(file)

        data = File.open(temp_filename, "rb") { |f| f.read }

        obj = JSON.parse(data)
        expect(obj).to have_key("sample_rate")
        expect(obj).to have_key("samples_per_pixel")
        expect(obj).to have_key("bits")
        expect(obj).to have_key("length")
        expect(obj).to have_key("data")
      end
    end

    describe "attributes" do
      it "should return sample rate in hertz" do
        expect(file.sample_rate).to eq(16000)
      end

      it "should return samples per pixel" do
        expect(file.samples_per_pixel).to eq(64)
      end

      it "should return waveform data resolution in bits" do
        expect(file.bits).to eq(8)
      end

      it "should not have a start time" do
        expect(file.start_time).to be_nil
      end

      it "should return number of min and max waveform data pairs" do
        expect(file.size).to eq(1800)
      end

      it "should return waveform data" do
        expect(file.min_sample(0)).to eq(0)
        expect(file.max_sample(0)).to eq(0)

        expect(file.min_sample(26)).to eq(-53)
        expect(file.max_sample(26)).to eq(64)

        expect(file.min_sample(206)).to eq(8)
        expect(file.max_sample(206)).to eq(17)

        expect(file.min_sample(217)).to eq(-15)
        expect(file.max_sample(217)).to eq(-1)

        expect(file.min_sample(1799)).to eq(0)
        expect(file.max_sample(1799)).to eq(0)
      end
    end
  end

  context "with valid 16-bit data file" do
    let(:filename) { "spec/data/test_file_stereo_16bit_64spp.dat" }
    let(:file) { AudioWaveform::WaveformDataFile.new(filename: filename) }

    describe "attributes" do
      it "should return sample rate in hertz" do
        expect(file.sample_rate).to eq(16000)
      end

      it "should return samples per pixel" do
        expect(file.samples_per_pixel).to eq(64)
      end

      it "should return waveform data resolution in bits" do
        expect(file.bits).to eq(16)
      end

      it "should not have a start time" do
        expect(file.start_time).to be_nil
      end

      it "should return number of min and max waveform data pairs" do
        expect(file.size).to eq(1800)
      end

      it "should return waveform data" do
        expect(file.min_sample(0)).to eq(0)
        expect(file.max_sample(0)).to eq(0)

        expect(file.min_sample(26)).to eq(-13606)
        expect(file.max_sample(26)).to eq(16602)

        expect(file.min_sample(206)).to eq(2166)
        expect(file.max_sample(206)).to eq(4512)

        expect(file.min_sample(217)).to eq(-4052)
        expect(file.max_sample(217)).to eq(-430)

        expect(file.min_sample(1799)).to eq(-8)
        expect(file.max_sample(1799)).to eq(7)
      end
    end
  end

  context "with a file containing no waveform data" do
    let(:filename) { "spec/data/zero_length.dat" }
    let(:file) { AudioWaveform::WaveformDataFile.new(filename: filename) }

    describe "attributes" do
      it "should return sample rate in hertz" do
        expect(file.sample_rate).to eq(16000)
      end

      it "should return samples per pixel" do
        expect(file.samples_per_pixel).to eq(64)
      end

      it "should return waveform data resolution in bits" do
        expect(file.bits).to eq(8)
      end

      it "should not have a start time" do
        expect(file.start_time).to be_nil
      end

      it "should return number of min and max waveform data pairs" do
        expect(file.size).to eq(0)
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
        expect(file.size).to eq(0)

        file.append(-99, 101).append(-49, 51)

        expect(file.size).to eq(2)
        expect(file.min_sample(0)).to eq(-99)
        expect(file.max_sample(0)).to eq(101)
        expect(file.min_sample(1)).to eq(-49)
        expect(file.max_sample(1)).to eq(51)
      end
    end

    describe "to_binary" do
      it "should return binary data" do
        output = file.to_binary

        expect(output.bytesize).to eq(20)

        fields = output.unpack("lLllL")
        expect(fields[0]).to eq(1) # version
        expect(fields[1]).to eq(0) # flags (16-bit)
        expect(fields[2]).to eq(44100)
        expect(fields[3]).to eq(512)
        expect(fields[4]).to eq(0)
      end
    end

    describe "to_json" do
      it "should return JSON string" do
        output = file.to_json

        data = JSON.parse(output)

        expect(data).to have_key("sample_rate")
        expect(data["sample_rate"]).to eq(44100)

        expect(data).to have_key("samples_per_pixel")
        expect(data["samples_per_pixel"]).to eq(512)

        expect(data).to have_key("bits")
        expect(data["bits"]).to eq(16)

        expect(data).to have_key("length")
        expect(data["length"]).to eq(0)

        expect(data).to have_key("data")
        expect(data["data"]).to be_instance_of(Array)
        expect(data["data"].size).to eq(0)

        expect(data).not_to have_key("start_time")
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
        expect(file.start_time).to eq(8.5)
      end
    end

    describe "to_json" do
      it "should include start_time field in output" do
        output = file.to_json

        data = JSON.parse(output)

        expect(data).to have_key("start_time")
        expect(data["start_time"]).to eq(8.5)
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
