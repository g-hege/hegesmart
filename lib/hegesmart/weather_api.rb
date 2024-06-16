class Weather_api

	def self.update 
		uri = URI.parse("#{Hegesmart.config.openweathermap.weather}");
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Get.new(uri.request_uri);
		req['Accept']        = 'application/json'
		response = http.request(req)
		if response.is_a?(Net::HTTPSuccess)
			body = JSON.load(response.body)
			rec = {
				timestamp: Time.at(body['dt']),
				main: body['weather'].first['main'],
				description: body['weather'].first['description'],
				icon: body['weather'].first['icon'],
				temp: body['main']['temp'],
				feels_like: body['main']['feels_like'],
				temp_min: body['main']['temp_min'],
				temp_max: body['main']['temp_max'], 
				pressure: body['main']['pressure'],  
				humidity: body['main']['humidity'],
				visibility: body['visibility'],
				wind_speed: body['wind']['speed'],
				wind_deg: body['wind']['deg'],
				clouds: body['clouds']['all']
			}
			Weather.insert(rec)
		end
	end

	def self.update_forecast
		uri = URI.parse("#{Hegesmart.config.openweathermap.forecast}");
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Get.new(uri.request_uri);
		req['Accept']        = 'application/json'
		response = http.request(req)
		if response.is_a?(Net::HTTPSuccess)
			body = JSON.load(response.body)
			body['list'].each do |b|
				rec = {
					timestamp: Time.at(b['dt']),
					main: b['weather'].first['main'],
					description: b['weather'].first['description'],
					icon: b['weather'].first['icon'],
					temp: b['main']['temp'],
					feels_like: b['main']['feels_like'],
					temp_min: b['main']['temp_min'],
					temp_max: b['main']['temp_max'], 
					humidity: b['main']['humidity'],
					visibility: b['visibility'],
					wind_speed: b['wind']['speed'],
					wind_deg: b['wind']['deg'],
					clouds: b['clouds']['all']
				}
				WeatherForecast.unrestrict_primary_key
				WeatherForecast.update_or_create({timestamp: rec[:timestamp]}, rec)
			end
		end
		WeatherForecast.where{timestamp < DateTime.now}.delete
	end




end