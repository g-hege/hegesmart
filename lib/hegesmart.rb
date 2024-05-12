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
       file "#{Hegesmart.root}/config/settings/config.yml"
    end
  rescue Errno::ENOENT => e
    $stderr.puts e.message
    exit 127
  end

  def self.authorize

    client_id =   Google::Auth::ClientId.from_file CREDENTIALS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: SHEET_TOKEN_PATH
    authorizer =  Google::Auth::UserAuthorizer.new client_id, SHEET_SCOPE, token_store

    user_id = "default"
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def self.init
    Sequel::Model.db = Sequel.connect(Settings.database.url)
    Sequel::Model.db.extension :pg_array
    Sequel::Model.plugin :update_or_create
    Sequel.split_symbols = true
    @db = Sequel::Model.db

    # Initialize the API
    @sheet_service = Google::Apis::SheetsV4::SheetsService.new
    @sheet_service.authorization = authorize
  end 

  def self.sheet_service
    @sheet_service 
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
    ImportEpex.import
    SheetApi.update_google_sheet
  end





end 