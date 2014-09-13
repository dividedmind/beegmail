require 'net/imap/gmail'
require 'yaml'

class GMailState
  def initialize state_path
    @state_path = state_path
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

  attr_accessor :secret

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

  def write_state
    FileUtils.mkdir_p state_path.parent
    File.write state_path, YAML.dump(@state)
  end

  def load_state
    @state = YAML.load File.read state_path
  rescue
    @state = {}
  end

  attr_reader :state_path
end
