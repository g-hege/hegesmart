class Homematic

	def self.device_recordings
		[
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
		hm_json['devices'].each do |dev|
			puts "#{dev[0]}: #{hm_json['devices'][dev[0]]['label']}"
		end;
	end

	def self.get_homematic_data
		hm_ret =''
		IO.popen('cd /home/hege/.venv/bin; ./hmip_cli --dump-configuration') do |io|
		  hm_ret =  io.read
		end;

	    r = hm_ret.sub(/^(.)*}/,"");
		hm_json = JSON.parse(r);
	end

end
