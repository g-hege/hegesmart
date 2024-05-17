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
			{device: 'switch1', 			topic: 'I4/status/input:1',		 				param: 'state',  unit: 'on/off'}
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
		@current_pool_apower = false
		@pool_override_switch = false
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
					@current_pool_apower = m[actual_dev[:param]] > 300 ? true : false
				when 'switch0' # pool pump permanent on
					@pool_override_switch = true if m[actual_dev[:param]]
					@time_last_switch = ((Time.new) - 60*2 )
					Hegesmart.logger.info "pool_override_switch TRUE" if @pool_override_switch
				when 'switch1' # pool pump permanent off
					@pool_override_switch = false if m[actual_dev[:param]] 
					@time_last_switch = ((Time.new) - 60*2 )
					Hegesmart.logger.info "pool_override_switch FALSE" if !@pool_override_switch
				else
					current_power(topic, m[actual_dev[:param]])
				end

				current_price = (Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10).to_f
				minmax =  Hegesmart.db.fetch('select min(marketprice) as min, max(marketprice) as max from epex e where date(timestamp) = CURRENT_DATE').first
				max_price = (minmax[:max]/10).to_f rescue 'na'
				min_price = (minmax[:min]/10).to_f rescue 'na'

				runtime_today = Hegesmart.db.fetch("select sum(runtime) from device_runtime where device = 'pool_pump' and date(starttimestamp) = CURRENT_DATE").first[:sum] rescue 0

				solar_power_this_day = Hegesmart.db.fetch("select sum(value) from consumption c  where device = 'solar' and date(timestamp) = CURRENT_DATE").first[:sum] rescue 0

				bitcoin = Crypto.where(slug: 'bitcoin').order(Sequel.desc(:last_updated)).get(:price) rescue 0
				bitcoin = bitcoin.to_f.round(2)

				hm_data = {}
				homematic_recordings.map {|hm| hm_data[hm] = Recordings.where(device: hm).order(Sequel.desc(:timestamp)).get(:value).to_f}

				ethereum = Crypto.where(slug: 'ethereum').order(Sequel.desc(:last_updated)).get(:price) rescue 0
				ethereum = ethereum.to_f.round(2)


				MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
			  		c.publish('c4/marketprice',  { price: current_price, max_price: max_price, min_price: min_price }.to_json  )
			  		c.publish('c4/currentpower', { apower: current_power().round(1), 
			  			                           consumption: (current_power() - @current_solar_power).round(1),
			  			                           solar_power_this_day: (solar_power_this_day.to_f / 1000).round(1)
			  			                         }.to_json )
			  		c.publish('c4/poolpump', { 	switch: "#{ @current_pool_state ? 'on' : 'off'}",
			  								    power:  "#{ @current_pool_apower ? 'on' : 'off'}", 
			  								    override: "#{@pool_override_switch ? 'on' : 'off'}",
							  					runtime:  (runtime_today.to_f / 60).round(1),
							  					runtime_id: @actual_runtime_id.nil? ? 'null' :  @actual_runtime_id,
							  					boiler: is_boiler_on() ? 'on' : 'off',
							  					time_last_switch: (Time.new - @time_last_switch).to_i
			  		                         }.to_json )
			  		c.publish('homematic/status', hm_data.to_json )			  		
			  		c.publish('crypto/status', { ethereum: ethereum, bitcoin: bitcoin }.to_json )
			  		c.publish('grogu/status', { uptime: Uptime.uptime }.to_json  )
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

				pump_runok = ((runtime_today.to_f / 60) < 6) && !is_boiler_on()

				if (@current_solar_power > 333 && pump_runok ) || 
				   (current_price < 6 && @current_solar_power > 30 && pump_runok ) ||  
				   @pool_override_switch
				   
					pool_pump(true)
				else
					pool_pump(false)
				end
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

end
