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

end
