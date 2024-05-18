class ConfigDb

	def self.get(name, defaultvalue)
		param = ConfigData.where(config_name: name).get(:value)
		param = defaultvalue if param.nil? 
		param
	end

	def self.set(name, value)
		ConfigData.unrestrict_primary_key
		ConfigData.update_or_create({config_name: name}, value: value)
		true
	end

end