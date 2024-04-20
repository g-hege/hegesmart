class Mqtt_api

	def self.subscribe
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.get('I4/status/#') do |topic,message|
	    		puts "#{topic}: #{message}"
	  		end
	  	end
	end

	def self.publish
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.publish('hege/status/grogu', 'hello')
		end
 	end


 	def self.marketprice
 		price = (Epex.where{timestamp < DateTime.now}.order(Sequel.desc(:timestamp)).get(:marketprice)/10).to_f
		MQTT::Client.connect(Hegesmart.config.mqtts) do |c|
	  		c.publish('c4/marketprice', { price: price }.to_json  )
		end
		puts 'send to mqtt broker'
		true
 	end

end
