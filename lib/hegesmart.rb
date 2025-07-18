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

  # Removed: puts "Loaded GoogleAuth version: #{Google::Auth::VERSION}"
  # This line caused the uninitialized constant error.

  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: SHEET_TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SHEET_SCOPE, token_store

  user_id = "default"
  credentials = authorizer.get_credentials user_id

  if credentials.nil?
    # NEU: Starte einen lokalen Server, um den Redirect abzufangen
    # Du kannst hier einen beliebigen freien Port wählen, z.B. 8080, 9000 etc.
    # Der URI muss mit dem in der Google Cloud Console übereinstimmen!
    redirect_uri = 'http://localhost:9001' # Muss mit der Cloud Console übereinstimmen

    begin
      # get_and_store_credentials_from_code kann nun einen block übergeben bekommen
      # Dieser Block wird aufgerufen, um den Autorisierungscode zu erhalten.
      # Wenn base_url angegeben ist, versucht der Authorizer einen lokalen Webserver zu starten.
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id,
        # base_url ist der lokale Redirect-URI, den du in der Cloud Console registriert hast
        base_url: redirect_uri
      )
    rescue StandardError => e
      puts "Ein unerwarteter Fehler ist bei der Autorisierung aufgetreten: #{e.message}"
      exit # Oder eine andere Fehlerbehandlung
    end
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