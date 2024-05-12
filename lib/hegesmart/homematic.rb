class Homematic

	def self.hmdevices
		[{id: '3014F711A00000D8A9A9E8F6' },
		 {id: '3014F711A00000DA4994C726' },
		 {id: '3014F711A00000DA499F082E' },
		 {id: '3014F711A00001DD89971945' },
		 {id: '3014F711A00000DA499F082E' },
 		 {id: '3014F711A00003D8A9A9F8AB' },
 		 {id: '3014F711A0000A18A9A658CA' },
 		 {id: '3014F711A0000A18A9AA275E' },
 		 {id: '3014F711A0000A18A9AA2760' },
 		 {id: '3014F711A0000A18A9AA2771' },
 		 {id: '3014F711A0000A18A9AA2773' },
 		 {id: '3014F711A0000A1D89983300' },
 		 {id: '3014F711A0000A1D899834EC' },
 		 {id: '3014F711A0000A9A499957DB' },
 		 {id: '3014F711A0000B5D898B2D5C' },
 		 {id: '3014F711A0000B9BE99E94D8' },
 		 {id: '3014F711A0000B9BE99E9792' },
 		 {id: '3014F711A0000B9D898A4BFA' }, 
 		 {id: '3014F711A0000EDBE9923FE3' }, 
 		 {id: '3014F711A0000EDBE992486B' },  
 		 {id: '3014F711A000109D8991B5F4' }, 
 		 {id: '3014F711A000281D89B3C44A' }
		]
	end

	def self.device_recordings
		[
		 {device: 'temp-pool', id: '3014F711A000281D89B3C44A', value: "['functionalChannels']['1']['temperatureExternalOne']"},
		 {device: 'temp-garden', id: '3014F711A0000EDBE9923FE3', value: "['functionalChannels']['1']['actualTemperature']"},
		 {device: 'humidity-garden', id: '3014F711A0000EDBE9923FE3', value: "['functionalChannels']['1']['humidity']"},
		 {device: 'temp-loggia', id: '3014F711A0000EDBE992486B', value: "['functionalChannels']['1']['actualTemperature']"},
		 {device: 'humidity-loggia', id: '3014F711A0000EDBE992486B', value: "['functionalChannels']['1']['humidity']"},
		 {device: 'temp-wz', id: '3014F711A0000A9A499957DB', value: "['functionalChannels']['1']['actualTemperature']"},
		 {device: 'humidity-wz', id: '3014F711A0000A9A499957DB', value: "['functionalChannels']['1']['humidity']"},
		]
	end

	def self.import_actual_homematic
		puts DateTime.now.strftime('%Y-%m-%d %H:%M')
		hm_json = Homematic.get_homematic_data()
		device_recordings.each do |dev|
			value = eval("hm_json['devices']['#{dev[:id]}']#{dev[:value]}")
			puts "#{dev[:device]}: #{value}"
			rec = {device: dev[:device], value: value}
			Recordings.insert(rec)
		end

	end

	def self.show_labels
		hm_json = Homematic.get_homematic_data()
		Homematic.hmdevices.each do |dev|
			puts "#{dev}: #{hm_json['devices'][dev[:id]]['label']}"
		end;
	end

	def self.get_homematic_data
		hm_ret =''
		IO.popen('cd /home/hege/.venv/bin; ./hmip_cli  --dump-configuration') do |io|
		  hm_ret =  io.read
		end;

	    r = hm_ret.sub(/^(.)*}/,"");
		hm_json = JSON.parse(r);
	end

end
