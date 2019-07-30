require 'bundler/setup'
Bundler.require
require 'zlib'
require 'net/imap'


#Net::IMAP.debug = true

class App < Thor
  include Thor::Actions
  default_task :crawl

  desc 'crawl', 'Crawls email to save mails'
  def crawl
    saved_info = []

    if yes? 'Save email contents (y/n)?'
      saved_key = 'RFC822'
    elsif yes? 'Save subjects (y/n)?'
      saved_key = 'BODY[HEADER]'
    else
      saved_key = 'BODY[HEADER.FIELDS.NOT (SUBJECT)]'
    end

    filter_headers = 'BODY[HEADER.FIELDS (FROM TO Subject)]'

    filter_messages = yes? 'Select messages individually (y/n)?'

    imap_server = ask 'imap server:'
    login = ask 'login:'
    password = ask 'password:'

    imap = Net::IMAP.new(imap_server, ssl: true)
    imap.login(login, password)
    imap.list('', '*').each do |mailbox|
      imap.examine mailbox.name
      messages_in_mailbox = imap.responses['EXISTS'][0]
      if messages_in_mailbox
        say "Searching #{mailbox.name}"
        ids = imap.search('SINCE 1-Jan-2012 NOT OR TO "@agilefant.org" CC "@agilefant.org"')
        if ids.empty?
          say "\tFound no messages"
        else
          if filter_messages
            filter_fetch = imap.fetch(ids, filter_headers)
            if filter_fetch
              i = 1
              ids = filter_fetch.select do |message|
                m = Mail.new message.attr[filter_headers]
                yes? "#{i}/#{filter_fetch.size} #{m.from.join(',')} --> #{m.to.join(',')} : #{m.subject}"
                i += 1
              end.map { |message| message.seqno }
            end
          end

          unless ids.empty?
            to_save_fetch = imap.fetch(ids, saved_key)
            if to_save_fetch
              to_save_fetch.each do |message|
                saved_info << message.attr[saved_key]
              end
            end
          end
        end
      else
        say "#{mailbox.name} does not have any messages"
      end
    end

    Zlib::GzipWriter.open('mail.json.gz') do |gz|
      gz.write JSON.generate(saved_info)
    end

    imap.logout
    imap.disconnect
  end
end

App.start
