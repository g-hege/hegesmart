class WstwApi

    AUTH_URL = "https://log.wien/auth/realms/logwien/protocol/openid-connect/"  
    API_URL_WSTW = "https://api.wstw.at/gateway/WN_SMART_METER_PORTAL_API_B2C/1.0/"

    def self.kundennummer
    	@kundennummer
    end

    def self.zaehlpunktnummer
    	@zaehlpunktnummer
    end

	def self.login 

        loginargs = {
            "client_id": "wn-smartmeter",
            "redirect_uri": "https://www.wienernetze.at/wnapp/smapp/",
            "response_mode": "fragment",
            "response_type": "code",
            "scope": "openid",
            "nonce": "",
            "prompt": "login",
        }
		login_uri = URI("#{AUTH_URL}auth?#{URI.encode_www_form(loginargs)}")
		response =  Net::HTTP.get_response(login_uri)
		return nil if !response.is_a?(Net::HTTPSuccess)
    	all_cookies = response.get_fields('set-cookie')
    	cookies_array = Array.new
    	all_cookies.each { | cookie |
        	cookies_array.push(cookie.split('; ')[0])
	    }
	    @wstw_cookies = cookies_array.join('; ')
		html_doc = Nokogiri::HTML(response.body)
		actionuri = html_doc.xpath('//form/@action').first.value rescue nil
		return nil if actionuri.nil?
	    uri = URI.parse(actionuri)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Post.new(uri.request_uri)
		req.set_form_data({'username' => Hegesmart.config.wstw.user, 'password' => Hegesmart.config.wstw.pwd})
		req['Cookie'] = @wstw_cookies
		req['allow_redirects'] = false
		response = http.request(req);
		if !response.is_a?(Net::HTTPFound)
			msg = "Wstw login failed! Check username/password."
			Hegesmart.logger.error msg 
			puts msg
			return nil
		end
		code = response.get_fields('location').first.split('&code=')[1] rescue nil;
	    uri = URI("#{AUTH_URL}token")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Post.new(uri.request_uri)
		req.set_form_data({ 'code' => code, 
                			'grant_type' => 'authorization_code',
                            'client_id' =>  'wn-smartmeter',
                			'redirect_uri' => 'https://www.wienernetze.at/wnapp/smapp/'})
		req['Cookie'] = @wstw_cookies
		response = http.request(req);
		token = JSON.load(response.body) if response.is_a?(Net::HTTPSuccess);
		@wstw_token = token['access_token'] rescue nil
		@wstw_refresh_token = token['refresh_token'] rescue nil
		expires_in = token['expires_in'] rescue 0
		@refresh_time = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i + expires_in - 5

		return nil if @wstw_token.nil?
		info = WstwApi.get('zaehlpunkte')
		@kundennummer = info.first['geschaeftspartner'] rescue nil
 	 	info = WstwApi.get('zaehlpunkt/baseInformation')
	 	@zaehlpunktnummer = info['zaehlpunkt']['zaehlpunktnummer'] rescue nil
		!@wstw_token.nil? && !@kundennummer.nil? && !@zaehlpunktnummer.nil?
	end

	def self.refresh_token
		@wstw_token = nil
		uri = URI("#{AUTH_URL}token")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Post.new(uri.request_uri)
		req.set_form_data({ 'grant_type' => 'refresh_token',
							'refresh_token' => @wstw_refresh_token, 
                            'client_id' =>  'wn-smartmeter'})
		req['Cookie'] = @wstw_cookies
		response = http.request(req);
		token = JSON.load(response.body) if response.is_a?(Net::HTTPSuccess);
		@wstw_token = token['access_token'] rescue nil
		@wstw_refresh_token = token['refresh_token'] rescue nil
		!@wstw_token.nil? 
	end

	def self.get(cmd, query: nil, debug: false)

		unless @wstw_token
			WstwApi.login
			return nil if @wstw_token.nil?		
		end

		WstwApi.refresh_token if @refresh_time < Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i 

		cmd += "#{cmd.include?('?') ? '&' : '?'}#{URI.encode_www_form(query)}" if !query.nil? 
		uri =  URI.parse("#{API_URL_WSTW}#{cmd}")
		puts uri if debug

		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		req =  Net::HTTP::Get.new(uri.request_uri)
		req['Authorization'] = "Bearer #{WstwApi.wstw_token}"
		req['Content-type']  = 'application/json'
		req['Accept']        = 'application/json'
		req['X-Gateway-APIKey'] = Hegesmart.config.wstw.apikey
		response = http.request(req)

		if response.is_a?(Net::HTTPUnauthorized)
			puts "HTTPUnauthorized"
		end

		return nil if !response.is_a?(Net::HTTPSuccess)
		body = JSON.load(response.body)
		body

 	end

	def self.import

		device = 'wienstrom'
		date_from =Consumption.where(device: device).max(:timestamp).to_date.next_day rescue Date.parse(Hegesmart.config.wstw.startdate)
		date_to = Date.today.prev_day
		for import_day in date_from..date_to do
			total_day = WstwApi.import_day(import_day)
			puts "import: #{device} #{import_day.strftime('%y-%m-%d')} -> #{total_day} W/h"
		end
		'done'
	end

 	def self.import_day(import_day, device: 'wienstrom')

		unless @wstw_token
			WstwApi.login
			return nil if @wstw_token.nil?		
		end
		if import_day.kind_of? String
			import_day = Time.parse("#{import_day}")
		else
			import_day = import_day.to_time
		end
		import_from =  import_day - 60*60 # substract 1 hour

        cmd = "messdaten/#{WstwApi.kundennummer}/#{WstwApi.zaehlpunktnummer}/verbrauch"

        query = {
            "dateFrom": import_from.strftime("%Y-%m-%dT23:00:00.000Z"),
            "period": 'DAY',
            "accumulate": false,
            "offset": 0,
            "dayViewResolution": 'HOUR'  
        }

	 	body = WstwApi.get(cmd, query: query, debug: false)
	 	return if body.nil?

		Consumption.where(device: device).where(Sequel.lit("Date(timestamp) = ?",import_day.strftime('%Y-%m-%d'))).delete
		insertrecs = body['values'].map { |h| { device: device, timestamp: (Time.parse(h['timestamp'])) + 60*60, value: h['value']}}
		Consumption.multi_insert(insertrecs)
		total_day = 0
		body['values'].each{|h| total_day +=  h['value'].round}
		total_day

	end

end
