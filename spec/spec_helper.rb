require 'rubygems'
require 'bundler/setup'

require 'logger'

Bundler.require :test

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    # Exclude test code from coverage report
    add_filter '/spec/'
    add_filter '/vendor/'
  end
end

# add lib to current path
$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'audio_waveform'
