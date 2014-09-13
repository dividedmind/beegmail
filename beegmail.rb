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
  XDG['CACHE'].with_subdirectory('beegmail').to_path + 'state.yml'
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

  new_ids = Hash[*({
    inbox: 'INBOX',
    all: '[Gmail]/All Mail',
    sent: '[Gmail]/Sent Mail',
    trash: '[Gmail]/Trash'
  }.map do |k, v|
    ids = gmail.new_ids(v)
    info "#{ids.length} new messages in #{k}"
    debug ids
    [k, ids]
  end).flatten(1)]

  archived = new_ids[:all] - new_ids[:inbox] - new_ids[:sent]

  info "#{archived.length} messages newly archived"
  debug archived

  processed = archived + new_ids[:trash]

  info "total #{processed.length} messages newly processed"
  debug processed

  unless processed.empty?
    bee.send 'gmail', processed.length
    info "successfully beeminded"
  end
end

go!
