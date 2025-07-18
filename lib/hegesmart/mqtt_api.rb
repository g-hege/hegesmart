class Mqtt_api

	def self.devices
		[
			{device: 'boiler',              topic: 'boiler/status/switch:0',	            param: 'apower', unit: 'Watt'},
			{device: 'workplace', 			topic: 'workplace/status/switch:0', 			param: 'apower', unit: 'Watt'},
			{device: 'tv', 					topic: 'tv/status/switch:0', 					param: 'apower', unit: 'Watt'},
			{device: 'washing-machine', 	topic: 'washing-machine/status/switch:0', 		param: 'apower', unit: 'Watt'},
 			{device: 'refrigerator-outside',topic: 'refrigerator-outside/status/switch:0',  param: 'apower', unit: 'Watt'},
			{device: 'kitchen', 			topic: 'kitchen/status/switch:0', 				param: 'apower', unit: 'Watt'},
			{device: 'dryer', 				topic: 'dryer/status/switch:0', 				param: 'apower', unit: 'Watt'},
			{device: 'pool', 				topic: 'pool/status/switch:0', 				    param: 'apower', unit: 'Watt'},
			{device: 'plug',	 			topic: 'plug/status/switch:0',	 				param: 'apower', unit: 'Watt'},	
			{device: 'solar', 				topic: 'solar/status/switch:0', 				param: 'apower', unit: 'Watt'},
			{device: 'switch0', 			topic: 'I4/status/input:0',		 				param: 'state',  unit: 'on/off'},
			{device: 'switch1', 			topic: 'I4/status/input:1',		 				param: 'state',  unit: 'on/off'},
			{device: 'min-solar-power', 	topic: 'c4set/min-solar-power',		 			param: 'power',  unit: 'Watt'},
			{device: 'max-market-price',	topic: 'c4set/max-market-price',	 			param: 'cent',   unit: 'Cent'},
			{device: 'daily-pump-runtime',	topic: 'c4set/daily-runtime',	 			    param: 'hours',  unit: 'Hours'}
		]
	end

	def self.homematic_recordings
		%w{temp-pool temp-garden humidity-garden temp-loggia humidity-loggia temp-wz humidity-wz}
	end

	def self.publish_c4

		mqtt_log("INITIALIZE")
		@current_solar_power = 0
		@actual_runtime_id = nil
		@current_pool_state = false
		@current_pool_pump_state = false
		@pool_override_switch = false
		@sunrise_sunset = {}
		@min_solar_power = ConfigDb.get('min_solar_power','100').to_i  # initial 100 watt
		@max_market_price = ConfigDb.get('max_market_price','6').to_i  # initial 6 cent
		@daily_pump_runtime = ConfigDb.get('daily_pump_runtime','6').to_f  # initial 6 hours
		pool_pump(false, initialize_switch: true)

		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.get('#') do |topic, message|
	  			actual_dev = Mqtt_api.devices.find{|d| topic == d[:topic]}
	  			next if actual_dev.nil?
  				m = JSON.parse(message)
  				topic = actual_dev[:device]
  				next if m[actual_dev[:param]].nil?

#				Hegesmart.logger.info "device: #{topic}: #{m[actual_dev[:param]]} #{actual_dev[:unit]}" 

				case topic
				when 'solar'
					@current_solar_power = m[actual_dev[:param]]
				when 'pool'
					@current_pool_pump_state = m[actual_dev[:param]] > 300 ? true : false
				when 'switch0' # pool pump permanent on
					@pool_override_switch = true if m[actual_dev[:param]]
					@time_last_switch = ((Time.new) - 60*2 )
					Hegesmart.logger.info "pool_override_switch TRUE" if @pool_override_switch
				when 'switch1' # pool pump permanent off
					@pool_override_switch = false if m[actual_dev[:param]] 
					@time_last_switch = ((Time.new) - 60*2 )
					Hegesmart.logger.info "pool_override_switch FALSE" if !@pool_override_switch
				when 'min-solar-power'
					@min_solar_power = m[actual_dev[:param]].to_i
					ConfigDb.set('min_solar_power', @min_solar_power.to_s)
					mqtt_log("set min solar power: #{@min_solar_power} #{m[actual_dev[:unit]]}")
				when 'max-market-price'
					@max_market_price = m[actual_dev[:param]].to_i
					ConfigDb.set('max_market_price', @max_market_price.to_s)
					mqtt_log("set max price: #{@max_market_price} #{m[actual_dev[:unit]]}")					
				when 'daily-pump-runtime'
					@daily_pump_runtime = m[actual_dev[:param]].to_f
					ConfigDb.set('daily_pump_runtime', @daily_pump_runtime.to_f)
					mqtt_log("set daily pump runtime: #{@daily_pump_runtime.to_f} #{m[actual_dev[:unit]]}")	
				else
					current_power(topic, m[actual_dev[:param]])
				end

				w = Weather.order(Sequel.desc(:timestamp)).first
				weather = {description: w.description,
							icon: "https://openweathermap.org/img/wn/#{w.icon}@2x.png",
							clouds: w.clouds,
							temp: w.temp.to_f,
							temp_min: w.temp_min.to_f,
							temp_max: w.temp_max.to_f,
							pressure: w.pressure,
							humidity: w.humidity,
							feels_like: w.feels_like.to_f,
							wind_speed: w.wind_speed.to_f,
							wind_deg: w.wind_deg
						}

				forecast = Hegesmart.db.fetch('select timestamp::date, min(temp), max(temp), max(wind_speed) as maxwind from public.weather_forecast group by timestamp::date order by timestamp')

				forecast_arr = []
				forecast.each do |fc|
					d = (fc[:timestamp] -  DateTime.now.to_date).to_i
					if d > 0 && d < 5
						forecast_arr << "#{fc[:timestamp].abbr_dayname} | min: #{'%.1f' % fc[:min].to_f} | max: #{'%.1f' % fc[:max].to_f} | wind: #{'%.1f' % fc[:maxwind].to_f} km/h"
					end
				end


				current_price = (Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10).to_f

				price_running_hours = Epex.where(Sequel.lit("timestamp::date = current_date and marketprice < ?",@max_market_price * 10)).count

				min_max_avg =  Hegesmart.db.fetch('select min(marketprice) as min, max(marketprice) as max, avg(marketprice) as avg from epex e where date(timestamp) = CURRENT_DATE').first
				max_price = (min_max_avg[:max]/10).to_f rescue 'na'
				min_price = (min_max_avg[:min]/10).to_f rescue 'na'
				avg_price = (min_max_avg[:avg]/10).to_f rescue 'na'

				runtime_today = Hegesmart.db.fetch("select sum(runtime) from device_runtime where device = 'pool_pump' and date(starttimestamp) = CURRENT_DATE").first[:sum] rescue 0

				usage_day1 = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'wienstrom' and date(timestamp) = CURRENT_DATE - 1").first[:sum] rescue 0
				usage_day2 = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'wienstrom' and date(timestamp) = CURRENT_DATE - 2").first[:sum] rescue 0
				usage_day3 = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'wienstrom' and date(timestamp) = CURRENT_DATE - 3").first[:sum] rescue 0

				usage_pump_this_day = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'pool' and date(timestamp) = CURRENT_DATE").first[:sum] rescue 0

				solar_power_this_day = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'solar' and date(timestamp) = CURRENT_DATE").first[:sum] rescue 0
				energy_this_day = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'energy' and date(timestamp) = CURRENT_DATE").first[:sum] rescue 0

				solar_week_data = {}
				Solarweek.each {|w| solar_week_data["d#{(1 + solar_week_data.count )}".to_sym] = w.solarenergie.to_f/1000}

				solar_forecast_today = SolarForecastDay.where(day: Date.today).get(:pv_estimate10).to_f rescue 0
				solar_forecast_tomorrow = SolarForecastDay.where(day: (Date.today + 1)).get(:pv_estimate10).to_f rescue 0

				bitcoin = Crypto.where(slug: 'bitcoin').order(Sequel.desc(:last_updated)).get(:price) rescue 0
				bitcoin = bitcoin.to_f.round(2)

				hm_data = {}
				homematic_recordings.map {|hm| hm_data[hm] = Recordings.where(device: hm).order(Sequel.desc(:timestamp)).get(:value).to_f}

				ethereum = Crypto.where(slug: 'ethereum').order(Sequel.desc(:last_updated)).get(:price) rescue 0
				ethereum = ethereum.to_f.round(2)

				if @sunrise_sunset[:date].nil? || @sunrise_sunset['date'] != DateTime.now.strftime('%Y-%m-%d')
					response = HTTParty.get(Hegesmart.config.sunrise_sunset_uri)
					@sunrise_sunset = response["results"]
					@sunrise_sunset['date'] = DateTime.now.strftime('%Y-%m-%d')
					%w{sunrise sunset solar_noon civil_twilight_begin civil_twilight_end nautical_twilight_begin nautical_twilight_end astronomical_twilight_begin astronomical_twilight_end}.each do |p|
						@sunrise_sunset[p] = Time.parse(@sunrise_sunset[p]).strftime('%H:%M')
					end
				end

# import shelly addone temperature

			uri = URI.parse("http://192.168.0.15/rpc/Temperature.GetStatus?id=100");
			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = uri.scheme == 'https'
			req =  Net::HTTP::Get.new(uri.request_uri);
			req['Accept']        = 'application/json'
			response = http.request(req)

			if response.is_a?(Net::HTTPSuccess)
				body = JSON.load(response.body)
				pooltemp = body['tC'].to_f.round(2)
			else
				pooltemp = '0'
			end


				MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
			  		c.publish('c4/marketprice', {  price: current_price.round(2), 
			  			                           max_price: max_price.round(2), 
			  			                           min_price: min_price.round(2),
			  			                           avg_price: avg_price.round(2),
			  			                           running_hours: price_running_hours
			  			                        }.to_json  )
			  		c.publish('c4/currentpower',{ energy_this_day: (energy_this_day.to_f / 1000).round(1),
			  																	apower: current_power().round(1), 
			  			                           consumption: (current_power() - @current_solar_power).round(1),
			  			                           solar_power_this_day: (solar_power_this_day.to_f / 1000).round(1),
			  			                           usage_pump_this_day: (usage_pump_this_day.to_f / 1000).round(1)
			  			                        }.to_json )
				  	c.publish('c4/poolpump', 	{ 	switch: "#{ @current_pool_state ? 'on' : 'off'}",
				  								    power:  "#{ @current_pool_pump_state ? 'on' : 'off'}", 
				  								    override: "#{@pool_override_switch ? 'on' : 'off'}",
								  					runtime:  (runtime_today.to_f / 60).round(1),
								  					runtime_id: @actual_runtime_id.nil? ? 'null' :  @actual_runtime_id,
								  					boiler: is_boiler_on() ? 'on' : 'off',
								  					time_last_switch: (Time.new - @time_last_switch).to_i,
								  					minsolar: "#{@min_solar_power}",
								  					maxprice: "#{@max_market_price}",
								  					daily_runtime: "#{(@daily_pump_runtime.to_f).round(1)}"
				  		                        }.to_json )
				  	c.publish('c4/usage', {  day1: (usage_day1.to_f / 1000).round(2), 
				  							 day2: (usage_day2.to_f / 1000).round(2),
				  		                     day3: (usage_day3.to_f / 1000).round(2)
				  		                  }.to_json )				  		                     
			  		c.publish('c4/solarweek', solar_week_data.to_json )
			  		c.publish('c4/solarforecast', {today: solar_forecast_today.round(2), tomorrow: solar_forecast_tomorrow.round(2) }.to_json )
			  		c.publish('homematic/status', hm_data.to_json )
			  		c.publish('crypto/status',  { ethereum: ethereum, bitcoin: bitcoin }.to_json )
			  		c.publish('sun/status',     @sunrise_sunset.to_json  )
			  		c.publish('grogu/status',   { uptime: Uptime.uptime }.to_json  )
			  		c.publish('c4/addon', {pool_temp: pooltemp}.to_json  )


					minute_now = DateTime.now.minute
			  		@prev_minute_now = minute_now - 1 if @prev_minute_now.nil?
			  		if @prev_minute_now != minute_now
			  			c.publish('weather', weather.to_json)
			  			@prev_minute_now = minute_now
						forecast_arr.reverse.each do |f|
			  				c.publish('forcast',{log: f}.to_json)
			  				sleep(0.5)
				  		end
			  		end

				end

				@current_pool_state = m['output'] if topic == 'pool'

				if @current_pool_state 
					if @actual_runtime_id.nil?
						@actual_runtime_id = DeviceRuntime.insert({device: 'pool_pump', starttimestamp: DateTime.now, stoptimestamp: DateTime.now}) 
					else
						DeviceRuntime.where(id: @actual_runtime_id ).update({stoptimestamp: DateTime.now})
					end
				else
					@actual_runtime_id = nil
				end

				cp_without_pool_pump = current_power() - Mqtt_api.get_current_power_of_device('pool')

# if boiler is on, don't run the pool pump ! 
# running time maximal 6 hours per day

				pump_runok = ((runtime_today.to_f / 60) < @daily_pump_runtime) && !is_boiler_on()

				if (@current_solar_power > @min_solar_power && pump_runok ) || 
				   (current_price < @max_market_price && @current_solar_power > 10 && pump_runok ) ||  
				   @pool_override_switch

					pool_pump(true)
				else
					pool_pump(false)
				end
	  			@max_market_price = ConfigDb.get('max_market_price','6').to_i  # initial 6 cent
	  		end
	  	end

	end

	def self.current_power(topic = nil, value = nil)
		if @cpower.nil?
			@cpower = {}
			Mqtt_api.devices.each {|d| @cpower[d[:topic]] = 0}
		end
		@cpower[topic] = value if !topic.nil?
		total = 0 
		@cpower.each {|d| total += d[1]}
		total
	end

	def self.get_current_power_of_device(topic)
		ret = @cpower[topic] rescue 0
		ret.nil? ? 0 : ret
	end

	def self.is_boiler_on()
		boiler_watt = get_current_power_of_device('boiler')
		boiler_watt > 1000 ? true : false
	end

	def self.pool_pump(on = true, initialize_switch: false)

		@current_pool_state = false if @current_pool_state.nil? || initialize_switch
		@time_last_switch = ((Time.new) - 60*2 ) if @time_last_switch.nil?

#		Hegesmart.logger.info "@time_last_switch: #{(Time.new - @time_last_switch).to_i} secounds | #{@actual_runtime_id} | #{on ? 'on' : 'off'}"
		# minimum 60 seconds between 2 switch events
		if (on != @current_pool_state && (Time.new - @time_last_switch) > 60) || initialize_switch
			@time_last_switch = Time.new
			MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  			c.publish('pool/rpc', {"id": "req", "src": "hegesmart","method": "Switch.set", "params":{"id": 0, "on": on }}.to_json  )
			end
			@current_pool_state = on
			mqtt_log("switch pool pump: #{on ? 'on' : 'off'}")
		end
		true

 	end

 	def self.mqtt_log(msg)
 		Hegesmart.logger.info msg
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
			c.publish('c4/log', { msg: "#{DateTime.now.strftime('%H:%M')} | #{msg}" }.to_json )
		end
	end


	def self.auto_adjust_max_market_price
		price_running_hours = 0
		for market_price in 1..10 do 
			running_hours = Epex.where(Sequel.lit("timestamp::date = current_date and marketprice < ?",market_price * 10)).count
			if running_hours > 3
				Mqtt_api.mqtt_log "set max market price: #{market_price} Cent -> #{running_hours} hours"
				price_running_hours = market_price
				break
			end
		end
		ConfigDb.set('max_market_price', price_running_hours.to_s)
		true
	end

end

class Date
  def dayname
     DAYNAMES[self.wday]
  end

  def abbr_dayname
    ABBR_DAYNAMES[self.wday]
  end
end
