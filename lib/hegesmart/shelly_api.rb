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

		['solar','boiler'].each do |device|
			date_from =Consumption.where(device: device).max(:timestamp).to_date.next_day rescue Date.parse(Hegesmart.config.shelly.startdate)
			date_to = Date.today.prev_day
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
		deviceid = Hegesmart.config.shelly.device[device] rescue nil
		return nil if deviceid.nil?
		param = {
			'id': deviceid,
			'channel': 0,
			'date_range': 'custom',
			'date_from': import_from.strftime("%Y-%m-%d %H:%M"),
			'date_to': import_to.strftime("%Y-%m-%d %H:%M")
		}
		uri =  URI.parse("#{ShellyApi.shelly_uri}/v2/statistics/power-consumption?#{URI.encode_www_form(param)}")
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
		body['history'].delete_if{|h| !h['missing'].nil?}
		insertrecs = body['history'].map { |h| { device: device, timestamp: Time.parse(h['datetime']), value: h['consumption'].round}}
		Consumption.multi_insert(insertrecs)
		total_day = 0
		body['history'].each{|h| total_day +=  h['consumption'].round}
		total_day
	end

end
