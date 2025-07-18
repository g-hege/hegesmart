class ShellyApi

	def self.shelly_token
		@shelly_token
	end

	def self.shelly_uri
		@shelly_uri
	end

	def self.login

		uri = URI.parse('https://api.shelly.cloud/auth/login')
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Post.new(uri.request_uri)
		req.set_form_data({'email' => Hegesmart.config.shelly.user,'password' => Hegesmart.config.shelly.pwd, 'var' => '2'})
		response = http.request(req);
		retjson = JSON.load(response.body) if response.is_a?(Net::HTTPSuccess);
		@shelly_token = retjson['data']['token'] rescue nil
		@shelly_uri = retjson['data']['user_api_url'] rescue nil
	end

	def self.import

		Hegesmart.config.shelly.device.each do |deviceconfig|
			device = deviceconfig[0]
			date_from = Consumption.where(device: device).max(:timestamp).to_date.prev_day rescue Date.parse(Hegesmart.config.shelly.device[device]['startdate'])
			date_to = Date.today
			for import_day in date_from..date_to do
				total_day = ShellyApi.import_day(device, import_day)
				puts "import: #{device} #{import_day.strftime('%y-%m-%d')} -> #{total_day} W/h"
			end
		end
		'done'
	end

	def self.import_day(device, import_day)

		unless @shelly_token
			ShellyApi.login
			return nil if @shelly_token.nil?		
		end
		if import_day.kind_of? String
			import_from = Time.parse("#{import_day}")
		else
			import_from = import_day.to_time
		end
		import_to =  import_from + 23*60*60
		deviceid = Hegesmart.config.shelly.device[device]['id'] rescue nil
		return nil if deviceid.nil?
		param = {
			'id': deviceid,
			'channel': 0,
			'date_range': 'custom',
			'date_from': import_from.strftime("%Y-%m-%d %H:%M"),
			'date_to': import_to.strftime("%Y-%m-%d %H:%M")
		}
		if Hegesmart.config.shelly.device[device]['type'] == 'em-3p'
			uri =  URI.parse("#{ShellyApi.shelly_uri}/v2/statistics/power-consumption/em-3p?#{URI.encode_www_form(param)}")
		else # pm1-plus
			uri =  URI.parse("#{ShellyApi.shelly_uri}/v2/statistics/power-consumption?#{URI.encode_www_form(param)}")
		end
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		req =  Net::HTTP::Get.new(uri.request_uri)
		req['Authorization'] = "Bearer #{ShellyApi.shelly_token}"
		req['Content-type']  = 'application/json'
		req['Accept']        = 'application/json'
		response = http.request(req)
		return nil if !response.is_a?(Net::HTTPSuccess)
		body = JSON.load(response.body)
		Consumption.where(device: device).where(Sequel.lit("Date(timestamp) = ?",import_from.strftime('%Y-%m-%d'))).delete
		total_day = 0
		if Hegesmart.config.shelly.device[device]['type'] == 'em-3p'
			body['sum'].delete_if{|h| !h['missing'].nil?}
			insertrecs = body['sum'].map { |h| { device: device, timestamp: Time.parse(h['datetime']), value: h['consumption'].round, reversed: h['reversed'].round}}
			body['sum'].each{|h| total_day +=  h['consumption'].round}
		else
			body['history'].delete_if{|h| !h['missing'].nil?}
			insertrecs = body['history'].map { |h| { device: device, timestamp: Time.parse(h['datetime']), value: h['consumption'].round}}
			body['history'].each{|h| total_day +=  h['consumption'].round}
		end
		Consumption.multi_insert(insertrecs)
		total_day
	end


	def self.update_market_price

		uri = URI("https://shelly-77-eu.shelly.cloud/v2/user/pp-ltu/#{Hegesmart.config.shelly.live_tarif_token}")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
		data = {price: ((Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10)/100).to_f.to_s}
		request.body = data.to_json
		response = http.request(request)
		if response.is_a?(Net::HTTPSuccess)
			puts "#{DateTime.now.strftime('%Y-%m-%d %H:%M')}: set current price to #{data[:price].to_f.to_s}€"
		elsif response.is_a?(Net::HTTPClientError)
		  # Client-Fehler (4xx Statuscode)
		  puts "Client-Fehler aufgetreten: #{response.code} #{response.message}"
		  puts "Antwort-Body: #{response.body}"
		elsif response.is_a?(Net::HTTPServerError)
		  # Server-Fehler (5xx Statuscode)
		  puts "Server-Fehler aufgetreten: #{response.code} #{response.message}"
		  puts "Antwort-Body: #{response.body}"
		else
		  # Andere Fehler oder Weiterleitungen (z.B. 3xx)
		  puts "Unerwarteter Statuscode: #{response.code} #{response.message}"
		  puts "Antwort-Body: #{response.body}"
		end
		
	end

end

