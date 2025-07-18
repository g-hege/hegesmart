require 'bundler/setup'
Bundler.require(:default)

require 'yaml'
require_relative '../lib/hegesmart'

require "fileutils"
require 'date'
require "csv"
require 'open-uri'
require 'uri'
require 'net/http'
require 'http-cookie'
require "google/apis/sheets_v4"
require "googleauth" 
require "googleauth/stores/file_token_store"
require "json"
require 'sys-uptime'
include Sys


    # google sheet service
    OOB_URI = Hegesmart.config.oauth.oob_url.freeze
    CREDENTIALS_PATH = "#{Hegesmart.root}/#{Hegesmart.config.oauth.credential_path}".freeze
    SHEET_APPLICATION_NAME = Hegesmart::config.oauth.sheet_application_name.freeze
    SHEET_TOKEN_PATH = Hegesmart::config.oauth.sheet_token_path.freeze
    SHEET_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS


# --- ADD THESE DEBUG LINES ---
puts "--- Debugging GoogleAuth ---"
puts "Google::Auth is defined: #{defined?(Google::Auth)}"
if defined?(Google::Auth)
  puts "Google::Auth::VERSION: #{Google::Auth::VERSION rescue 'Not available directly'}"
  puts "Google::Auth::UserAuthorizer is defined: #{defined?(Google::Auth::UserAuthorizer)}"
  if defined?(Google::Auth::UserAuthorizer)
    puts "Location of Google::Auth::UserAuthorizer: #{Google::Auth::UserAuthorizer.instance_method(:initialize).source_location[0] rescue 'Could not get source location'}"
    puts "Google::Auth::UserAuthorizer::PortNotAvailableError is defined: #{defined?(Google::Auth::UserAuthorizer::PortNotAvailableError)}"
  end
end
puts "--- End Debugging ---"
# --- END DEBUG LINES ---


Hegesmart::init


%w[models / ].each do |section|
  Dir.glob(File.join(Hegesmart.root, 'lib', 'hegesmart', section, '*.rb')).each do |f|
    require f
  end
end


