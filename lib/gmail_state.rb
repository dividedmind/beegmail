require 'net/imap/gmail'
require 'yaml'

class GMailState
  def initialize state_path
    @state_path = state_path
    load_state
  end

  attr_accessor :secret
  attr_accessor :logger

  def processed
    all_new = new_ids "[Gmail]/All Mail"
    new_sent = new_ids "[Gmail]/Sent Mail"
    new_draft = new_ids "[Gmail]/Drafts"

    all_inbox = inbox_ids
    old_inbox = state['INBOX'][:messages] || [] rescue []
    new_inbox = all_inbox - old_inbox

    newly_trashed = new_ids "[Gmail]/Trash"
    processed_by_rule = all_new - new_sent - new_draft - new_inbox
    newly_archived = old_inbox - all_inbox - newly_trashed

    state['INBOX'] = { messages: all_inbox }

    newly_trashed + processed_by_rule + newly_archived
  end

  def write_state
    FileUtils.mkdir_p state_path.parent
    File.write state_path, YAML.dump(@state)
  end

  private

  def inbox_ids
    mailbox = 'INBOX'

    imap.examine 'INBOX'

    uidvalidity = imap.responses['UIDVALIDITY'].first
    uidnext = imap.responses['UIDNEXT'].first

    result = gm_ids(1...uidnext)

    logger.info "#{result.length} total messages in #{mailbox}"
    logger.debug result

    result
  end

  # GMail msg ids of new messages in the designated mailbox
  def new_ids mailbox
    result = []
    imap.examine mailbox

    uidvalidity = imap.responses['UIDVALIDITY'].first
    uidnext = imap.responses['UIDNEXT'].first

    if (mbox_state = state[mailbox]) && (mbox_state[:uidvalidity] == uidvalidity)
      result = gm_ids(mbox_state[:uidnext]...uidnext)
    end

    state[mailbox] = { uidvalidity: uidvalidity, uidnext: uidnext }

    logger.info "#{result.length} new messages in #{mailbox}"
    logger.debug result

    return result
  end

  def gm_ids uids
    messages = imap.uid_fetch(uids, %w(X-GM-MSGID))
    return messages.map { |m| m.attr['X-GM-MSGID'] } if messages
    return []
  end

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

  def load_state
    @state = (YAML.load File.read(state_path)) || {}
  rescue
    @state = {}
  end

  attr_reader :state_path
end
