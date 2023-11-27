module Hegesmart

  def self.application_name
    "hegesmart".freeze
  end

  def self.root
    @root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end

  def self.env
    @env ||= (ENV['HEGESMART'] || 'staging')
  end

  begin
    Settings = ConfigSpartan.create do
       file "#{Hegesmart.root}/config/settings.yml"
#      file "#{EventWebsync.root}/config/settings/#{EventWebsync.env}.yml"
    end
  rescue Errno::ENOENT => e
    $stderr.puts e.message
    exit 127
  end

  def self.init
    Sequel::Model.db = Sequel.connect(Settings.database.url)
    Sequel::Model.db.extension :pg_array
    Sequel::Model.plugin :update_or_create
    Sequel.split_symbols = true
    @db = Sequel::Model.db
  end 

  def self.db
    Sequel::Model.db
  end


  def self.config
    Settings
  end

  def self.logger
    unless @logger
      @logger = Logger.new("#{Hegesmart.root}/#{Settings.logger.file}")
      @logger.level = eval(Settings.logger.level)
    end
    @logger
  end

  def self.sync 
    WstwApi.import 
    ShellyApi.import
  end

end 