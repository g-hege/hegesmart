class Mqtt_api

	def self.devices
		[
			{topic: 'boiler', param: 'apower'},
			{topic: 'workplace', param: 'apower'},
			{topic: 'tv', param: 'apower'},
			{topic: 'washing-machine', param: 'apower'},
 			{topic: 'refrigerator-outside', param: 'apower'},
			{topic: 'kitchen', param: 'apower'},
			{topic: 'dryer', param: 'apower'},
			{topic: 'pool', param: 'apower'},
			{topic: 'plug', param: 'apower'}	
		]
	end

	def self.current_power(topic, value)
		if @cpower.nil?
			@cpower = {}
			Mqtt_api.devices.each {|d| @cpower[d[:topic]] = 0}
		end
		@cpower[topic] = value
		total = 0 
		@cpower.each {|d| total +=  d[1]}
		total
	end

	def self.publish_c4
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.get('#') do |topic, message|
	  			t = Mqtt_api.devices.find{|d| (topic.start_with? d[:topic]) && topic.include?('status') }
	  			if !t.nil?
	  				m = JSON.parse(message)
	  				topic = topic.split('/').first
	  				if !m[t[:param]].nil? 
	  					cp = current_power(topic, m[t[:param]])
	  					price = (Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10).to_f
	  					minmax =  Hegesmart.db.fetch('select min(marketprice)as min, max(marketprice) as max from epex e where date(timestamp) =  CURRENT_DATE').first
	  					max_price = (minmax[:max]/10).to_f
	  					min_price = (minmax[:min]/10).to_f
#	    				puts "current power: #{cp.round(1)} Watt"
						MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
					  		c.publish('c4/marketprice', { price: price, max_price: max_price, min_price: min_price }.to_json  )
					  		c.publish('c4/currentpower', { apower: cp.round(1) }.to_json  )
						end	    				
	    			end
	    		end
	  		end
	  	end

	end

	def self.publish_test
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.publish('hege/status/grogu', 'hello')
		end
 	end

 	def self.marketprice
 		price = (Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10).to_f
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.publish('c4/marketprice', { price: price }.to_json  )
		end
		puts "#{DateTime.now.strftime("%Y-%m-%d %H:%M")} | price: #{price} send to mqtt broker"
		true
 	end

end
