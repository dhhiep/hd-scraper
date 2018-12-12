require 'selenium-webdriver'
require 'chromedriver-helper'
require 'rubygems'
require 'pry'
require 'sendgrid-ruby'
require 'base64'
require 'fileutils'
require 'dotenv/load'
require 'redis'

class Scraper
  include SendGrid

  @@driver = nil
  @@redis = nil


  def self.main
    emails = ENV['EMAILS'].split(',')
    current_session.navigate.to 'https://google.com.vn'
    capture_screen(emails: emails)
    # EXAMPLE
    # search_field.send_key(Selenium::WebDriver::Keys::KEYS[:backspace])
  end


  def self.current_session
    @@driver ||= create_selenium_session
  end

  def self.create_selenium_session
    puts "Creating browser for #{ENV['SELENIUM_TYPE'] || 'destop'}"

    default_capabilities = {
      args: %w(start-maximized disable-infobars disable-extensions)
    }

    default_capabilities.merge!(binary: ENV['GOOGLE_CHROME_SHIM']) if ENV.fetch('GOOGLE_CHROME_SHIM', nil)

    capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(chromeOptions: default_capabilities)

    case ENV['SELENIUM_TYPE']
    when 'heroku'
      Selenium::WebDriver.for :chrome, desired_capabilities: capabilities # for heroku
    when 'ubuntu'
      Selenium::WebDriver.for :remote, url: "http://127.0.0.1:9515", desired_capabilities: capabilities
    else
      Selenium::WebDriver.for :chrome, desired_capabilities: capabilities # for destop
    end
  end

  def self.clear_all_cookies
    redis_store('previous_cookies', nil)
  end

  def self.store_all_cookies
    redis_store('previous_cookies', current_session.manage.all_cookies.to_json)
  end

  def self.restore_all_cookies
    return false unless redis_load('previous_cookies').is_a?(Array)
    redis_load('previous_cookies').each do |cookie|
      cookie[:expires] = Time.parse(cookie[:expires]) if cookie[:expires]
      current_session.manage.add_cookie(cookie)
    end
  end

  def self.capture_screen(emails: [])
    @@folder_path = File.join(File.dirname(__FILE__), "screenshots")
    FileUtils.mkdir_p(@@folder_path)
    filename = "screenshot_#{Time.now.to_i}.png"
    file_path = File.join(@@folder_path, filename)
    current_session.manage.window.resize_to(1366, 768)
    sleep(0.5)
    current_session.save_screenshot(file_path)
    send_emails(emails: emails, file_path: file_path) if emails.any?
  end

  def self.send_emails(emails: [], file_path: nil)
    puts "Sending screenshot to email #{emails.join(', ')}"
    emails.each do |email|
      from = SendGrid::Email.new(email: 'screenshot@hiepdinh.info')
      to = SendGrid::Email.new(email: email)
      subject = 'The screenshot from Scraper'
      content = SendGrid::Content.new(type: 'text/plain', value: 'This is screenshot')
      mail = SendGrid::Mail.new(from, subject, to, content)

      attachment = Attachment.new
      attachment.content = Base64.strict_encode64(open(file_path).to_a.join)
      attachment.type = 'image/png'
      attachment.filename = file_path.split('/')[-1]
      attachment.disposition = 'attachment'
      attachment.content_id = 'Screenshot'
      mail.add_attachment(attachment)

      sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
      puts sg.client.mail._('send').post(request_body: mail.to_json).inspect
    end
  end

  def self.redis_connection
    @@redis ||= Redis.new(url: ENV['REDIS_URL'])
  end

  def self.redis_store(phone, data)
    puts "Storing data for #{phone} ... OK"
    data = data.to_json if data.is_a?(Hash)
    redis_connection.set(phone, data)
    redis_load(phone)
  end

  def self.redis_load(phone)
    print "Loading data for #{phone} ... "
    data = redis_connection.get(phone)

    if data
      print "OK\n"
      JSON.parse(data, symbolize_names: true) rescue nil
    else
      print "Fail (maybe key not existed)\n"
    end
  end
end

Scraper.main
