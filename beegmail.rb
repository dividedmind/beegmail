#!/usr/bin/env ruby

require 'bundler/setup'

require 'methadone'

$: << File.expand_path '../lib', __FILE__

require 'gmail_state'

include Methadone::Main
include Methadone::CLILogging

main do
end

go!
