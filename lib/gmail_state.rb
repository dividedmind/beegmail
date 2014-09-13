require 'net/imap/gmail'
require 'yaml'
require 'xdg'
require 'wrong'

class GMailState
  include Wrong

  def initialize
    load_state
  end

  # GMail msg ids of new messages in the designated mailbox
  def new_ids mailbox
    result = []
    imap.examine mailbox

    uidvalidity = imap.responses['UIDVALIDITY'].first
    uidnext = imap.responses['UIDNEXT'].first

    if (mbox_state = state[mailbox]) && (mbox_state[:uidvalidity] == uidvalidity)
      messages = imap.uid_fetch(mbox_state[:uidnext]...uidnext, %w(X-GM-MSGID))
      result = messages.map { |m| m.attr['X-GM-MSGID'] } if messages
    end

    save_state mailbox, uidvalidity: uidvalidity, uidnext: uidnext

    return result
  end

  private

  attr_reader :state

  def imap
    @imap ||= Net::IMAP::Gmail.new('imap.gmail.com', ssl: true).tap do |imap|
      imap.authenticate 'PLAIN', username, password
    end
  end

  def username
    secret['username']
  end

  def password
    secret['password']
  end

  def save_state mailbox, mbox_state
    state[mailbox] = mbox_state
    write_state
  end

  def secret
    return @secret if @secret

    assert { File.exists? secret_path }
    deny { File.world_readable? secret_path }
    @secret = YAML.load File.read secret_path

    return @secret
  end

  def write_state
    FileUtils.mkdir_p cache_path.parent
    File.write state_path, YAML.dump(@state)
  end

  def load_state
    @state = YAML.load File.read state_path
  rescue
    @state = {}
  end

  def secret_path
    XDG['CONFIG'].with_subdirectory('beegmail').to_path + 'secret.yml'
  end

  def state_path
    XDG['CACHE'].with_subdirectory('beegmail').to_path + 'state.yml'
  end
end
