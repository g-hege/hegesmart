class Mqtt_api

	def self.devices
		[
			{topic: 'boiler',	 			param: 'apower'},
			{topic: 'workplace', 			param: 'apower'},
			{topic: 'tv', 					param: 'apower'},
			{topic: 'washing-machine', 		param: 'apower'},
 			{topic: 'refrigerator-outside', param: 'apower'},
			{topic: 'kitchen', 				param: 'apower'},
			{topic: 'dryer', 				param: 'apower'},
			{topic: 'pool', 				param: 'apower'},
			{topic: 'plug',	 				param: 'apower'},	
			{topic: 'solar', 				param: 'apower'}				
		]
	end

	def self.publish_c4

		mqtt_log("INITIALIZE")
		@current_solar_power = 0
		@actual_runtime_id = nil
		@current_pool_state = false
		pool_pump(false, initialize_switch: true)
		cp = 0
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.get('#') do |topic, message|

	  			t = Mqtt_api.devices.find{|d| (topic.start_with? d[:topic]) && topic.include?('status') }

	  			next if t.nil?
  				m = JSON.parse(message)
  				topic = topic.split('/').first
  				next if m[t[:param]].nil?

				Hegesmart.logger.info "device: #{topic}: #{m[t[:param]].round(1)} Watt" 

				if topic == 'solar'
					@current_solar_power = m['apower']
				else
					cp = current_power(topic, m[t[:param]])
				end
				current_price = (Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10).to_f
				minmax =  Hegesmart.db.fetch('select min(marketprice) as min, max(marketprice) as max from epex e where date(timestamp) = CURRENT_DATE').first
				max_price = (minmax[:max]/10).to_f rescue 'na'
				min_price = (minmax[:min]/10).to_f rescue 'na'

				runtime_today = Hegesmart.db.fetch("select sum(runtime) from device_runtime where device = 'pool_pump' and date(starttimestamp) = CURRENT_DATE").first[:sum] rescue 0

				bitcoin = Crypto.where(slug: 'bitcoin').order(Sequel.desc(:last_updated)).get(:price) rescue 0
				bitcoin = bitcoin.to_f.round(2)

				ethereum = Crypto.where(slug: 'ethereum').order(Sequel.desc(:last_updated)).get(:price) rescue 0
				ethereum = ethereum.to_f.round(2)

				MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
			  		c.publish('c4/marketprice', { price: current_price, max_price: max_price, min_price: min_price }.to_json  )
			  		c.publish('c4/currentpower', { apower: cp.round(1), consumption: (cp - @current_solar_power).round(1)  }.to_json )
			  		c.publish('c4/poolpump', { switch: "#{ @current_pool_state ? 'on' : 'off'}", runtime:  (runtime_today.to_f / 60).round(1)}.to_json )
			  		c.publish('crypto/status', { ethereum: ethereum, bitcoin: bitcoin }.to_json )
				end

				@current_pool_state = m['output'] if topic == 'pool'

				cp_without_pool_pump = cp - Mqtt_api.get_current_power_of_device('pool')

				if (@current_solar_power > 300 && cp_without_pool_pump < 800 ) || (current_price < 9 && @current_solar_power > 30) 
					pool_pump(true)
				else
					pool_pump(false)
				end
	  		end
	  	end

	end

	def self.current_power(topic, value)
		if @cpower.nil?
			@cpower = {}
			Mqtt_api.devices.each {|d| @cpower[d[:topic]] = 0}
		end
		@cpower[topic] = value
		total = 0 
		@cpower.each {|d| total += d[1]}
		total
	end

	def self.get_current_power_of_device(topic)
		ret = @cpower[topic] rescue 0
		ret.nil? ? 0 : ret
	end

	def self.pool_pump(on = true, initialize_switch: false)

		@current_pool_state = false if @current_pool_state.nil? || initialize_switch
		@suppress_last_switchtime = ((Time.new) - 60*2 )if @suppress_last_switchtime.nil?
		DeviceRuntime.where(id: @actual_runtime_id ).update({stoptimestamp: DateTime.now}) if on == true && !@actual_runtime_id.nil?
#		Hegesmart.logger.info "@suppress_last_switchtime: #{(Time.new - @suppress_last_switchtime).to_i} secounds | #{@actual_runtime_id}"
		# minimum 90 seconds between 2 switch events
		if (on != @current_pool_state && (Time.new - @suppress_last_switchtime) > 90) || initialize_switch
			@suppress_last_switchtime = Time.new
			MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  			c.publish('pool/rpc', {"id": "req", "src": "hegesmart","method": "Switch.set", "params":{"id": 0, "on": on }}.to_json  )
			end
			
			@current_pool_state = on

			if on == true 
				@actual_runtime_id = DeviceRuntime.insert({device: 'pool_pump', starttimestamp: DateTime.now, stoptimestamp: DateTime.now}) 
			else
				@actual_runtime_id = nil
			end
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
