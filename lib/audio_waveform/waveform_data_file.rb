require 'json'

module AudioWaveform

  # Provides access to audio waveform data, and serialization to and from
  # binary and JSON data formats.
  #
  class WaveformDataFile

    # @param args [Hash]
    #
    # @option args [String] :filename Loads the specified binary waveform data
    #   file.
    #
    # @option args [Integer] :sample_rate
    # @option args [Integer] :samples_per_pixel
    # @option args [Integer] :bits
    # @option args [Numeric, nil] :start_time Start time, in seconds, or nil
    #   if no start time to be set.
    #
    def initialize(args)
      if args[:filename]
        read(args[:filename])
      else
        self.sample_rate       = args[:sample_rate]
        self.samples_per_pixel = args[:samples_per_pixel]
        self.bits              = args[:bits]
        self.start_time        = args[:start_time]

        @data = []
      end
    end

    # @return [Integer] Audio sample rate, in Hz.
    #
    def sample_rate
      @sample_rate
    end

    # @param sample_rate [Integer] Audio sample rate, in Hz. Must be greater
    #   than zero.
    #
    def sample_rate=(sample_rate)
      if sample_rate <= 0
        raise Error, "Invalid sample rate: #{sample_rate}"
      else
        @sample_rate = sample_rate
      end
    end

    # @return [Integer] Number of audio samples per waveform minimum/maximum
    #   pair.
    #
    def samples_per_pixel
      @samples_per_pixel
    end

    # Sets the waveform data scaling.
    #
    # @param samples_per_pixel [Integer] Number of audio samples per waveform
    #   minimum/maximum pair.
    #
    def samples_per_pixel=(samples_per_pixel)
      if samples_per_pixel <= 0
        raise Error, "Invalid samples per pixel: #{samples_per_pixel}"
      else
        @samples_per_pixel = samples_per_pixel
      end
    end

    # @return [Integer] Resolution of waveform data points, either 8 or 16 bits.
    #
    def bits
      @bits
    end

    # Sets the resolution of waveform data points.
    #
    # @param bits [Integer] Number of bits, must be either 8 or 16 bits
    #
    def bits=(bits)
      if bits != 8 && bits != 16
        raise Error, "Invalid bits: #{bits}"
      else
        @bits = bits
      end
    end

    # @return [Numeric, nil] Start time of the waveform data, in seconds, or
    #   nil if not set.
    #
    def start_time
      @start_time
    end

    #
    # Sets the start time of the waveform data.
    #
    # @param start_time [Numeric, nil] Start time of the waveform data, in
    #   seconds, or nil if none.
    #
    def start_time=(start_time)
      if start_time.nil?
        @start_time = nil
      elsif start_time < 0
        raise Error, "Invalid start time: #{start_time}"
      else
        @start_time = start_time
      end
    end

    # Writes the waveform data to file in JSON format.
    #
    # @param filename [String] The name of the file to write.
    # @return [WaveformDataFile] The current object.
    #
    def save_as_json(filename)
      File.open(filename, "w") do |file|
        file.write(to_json)
      end

      self
    end

    # Writes the waveform data to file in binary (.dat) format.
    #
    # @param filename [String] The name of the file to write.
    # @return [WaveformDataFile] The current object.
    #
    def save_as_binary(filename)
      File.open(filename, "wb") do |file|
        file.write(to_binary)
      end

      self
    end

    # @return [Hash] A hash representation of the waveform data file.
    #
    def to_hash
      obj = {
        sample_rate:       @sample_rate,
        bits:              @bits,
        samples_per_pixel: @samples_per_pixel,
        length:            @data.size / 2,
        data:              @data
      }

      if @start_time
        obj[:start_time] = @start_time
      end

      obj
    end

    # @return [String] A JSON representation of the waveform data file.
    #
    def to_json
      JSON.generate(to_hash)
    end

    # @return [String] A binary representation of the waveform data file.
    #
    def to_binary
      if @bits == 8
        flags  = FLAG_8_BIT
        format = "c*"
      else
        flags  = 0
        format = "s*"
      end

      output = encode_header(1, flags, @sample_rate, @samples_per_pixel, size)
      output += @data.pack(format)
      output
    end

    # Appends a waveform minimum/maximum pair.
    #
    # @param min_sample [Integer] Minimum audio sample amplitude value.
    # @param max_sample [Integer] Maximum audio sample amplitude value.
    #
    # @return [WaveformDataFile] The current object.
    #
    def append(min_sample, max_sample)
      @data << min_sample
      @data << max_sample

      self
    end

    # @return [Integer] The minimum waveform data point at the specified index.
    #
    def min_sample(index)
      @data[2 * index]
    end

    # @return [Integer] The maximum waveform data point at the specified index.
    #
    def max_sample(index)
      @data[2 * index + 1]
    end

    # @return [Integer] Length of waveform data (number of minimum/maximum
    #   value pairs).
    #
    def size
      @data.size / 2
    end

    private

    # Header format:
    # version           - 4 byte signed integer
    # flags             - 4 byte unsigned integer
    # sample_rate       - 4 byte signed integer
    # samples_per_pixel - 4 byte signed integer
    # size              - 4 byte unsigned integer

    HEADER_FORMAT = "lLllL"
    HEADER_SIZE   = 20
    FLAG_8_BIT    = 1

    def read(filename)
      # TODO: loading of JSON data from file

      File.open(filename, "rb") do |file|
        size = read_header(file)
        read_data(file, size)
      end
    end

    def encode_header(version, flags, sample_rate, samples_per_pixel, size)
      [version, flags, sample_rate, samples_per_pixel, size].pack(HEADER_FORMAT)
    end

    def decode_header(header)
      header.unpack(HEADER_FORMAT)
    end

    # @param file [File] The input file to read from.
    # @return [Integer] Number of waveform data points, from Length header field.
    #
    def read_header(file)
      header = file.read(HEADER_SIZE)

      if header.nil? || header.bytesize != HEADER_SIZE
        raise Error, "Failed to read file header"
      end

      version, flags, self.sample_rate, self.samples_per_pixel, size = decode_header(header)

      if version != 1
        raise Error, "Cannot load data file version: #{version}"
      end

      if (flags & FLAG_8_BIT) != 0
        @bits = 8
      else
        @bits = 16
      end

      size
    end

    # @param file [File] The input file to read from.
    # @param size [Integer] Number of waveform data points to read.
    #
    def read_data(file, size)
      if @bits == 8
        format = 'c*' # Array of 8-bit signed integers
      elsif @bits == 16
        format = 's*' # Array of 16-bit signed integers
      end

      length = size * (@bits / 8) * 2

      raw_data = file.read(length)

      if raw_data
        @data = raw_data.unpack(format)
      else
        @data = []
      end
    end
  end
end
