#!/usr/bin/env ruby

require 'bundler/setup'

require 'methadone'
require 'xdg'
require 'wrong'
require 'active_support'
require 'beeminder'

$: << File.expand_path('../lib', __FILE__)

require 'gmail_state'

include Methadone::Main
include Methadone::CLILogging
include Wrong

def state_path
  XDG['DATA'].with_subdirectory('beegmail').to_path + 'state.yml'
end

def secret
  return @secret if @secret

  assert { File.exists? secret_path }
  deny { File.world_readable? secret_path }
  @secret = YAML.load File.read secret_path

  return @secret
end

def secret_path
  XDG['CONFIG'].with_subdirectory('beegmail').to_path + 'secret.yml'
end

def bee
  @bee ||= Beeminder::User.new secret['beeminder']['auth_token']
end

main do
  gmail = GMailState.new state_path
  gmail.secret = secret['gmail']
  gmail.logger = logger

  processed = gmail.processed

  info "total #{processed.length} messages newly processed"
  debug processed

  unless processed.empty?
    bee.send 'gmail', processed.length
    info "successfully beeminded"
  end
end

go!
