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
require 'googleauth'
require 'googleauth/stores/file_token_store'

    # google sheet service
    OOB_URI = Hegesmart.config.oauth.oob_url.freeze
    CREDENTIALS_PATH = "#{Hegesmart.root}/#{Hegesmart.config.oauth.credential_path}".freeze
    SHEET_APPLICATION_NAME = Hegesmart::config.oauth.sheet_application_name.freeze
    SHEET_TOKEN_PATH = Hegesmart::config.oauth.sheet_token_path.freeze
    SHEET_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS


Hegesmart::init


%w[models / ].each do |section|
  Dir.glob(File.join(Hegesmart.root, 'lib', 'hegesmart', section, '*.rb')).each do |f|
    require f
  end
end


