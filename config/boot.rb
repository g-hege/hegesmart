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

Hegesmart::init


%w[models / ].each do |section|
  Dir.glob(File.join(Hegesmart.root, 'lib', 'hegesmart', section, '*.rb')).each do |f|
    require f
  end
end


