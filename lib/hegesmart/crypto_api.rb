class Crypto_api

	def self.update 

		even_hour = DateTime.now.hour % 2 == 0 
		uri = URI.parse("#{Hegesmart.config.coinmarketcap.url}/v1/cryptocurrency/listings/latest");
		params = {'start' => 1,'limit' => 500, 'convert' => 'EUR'}
		uri.query = URI.encode_www_form(params)

		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Get.new(uri.request_uri);
		req['Accept']        = 'application/json'

		if DateTime.now.hour % 2 == 0
			req['X-CMC_PRO_API_KEY'] = Hegesmart.config.coinmarketcap.auth_key
		else
			req['X-CMC_PRO_API_KEY'] = Hegesmart.config.coinmarketcap.auth_key_2
		end

		response = http.request(req)

		if response.is_a?(Net::HTTPUnauthorized)
			msg = "Crypto_api HTTPUnauthorized!"
			Hegesmart.logger.error msg
			puts msg
		end

		if response.is_a?(Net::HTTPTooManyRequests)
			msg = "Crypto_api Too Many Requests!"
			Hegesmart.logger.error msg
			puts msg
		end

		return nil if !response.is_a?(Net::HTTPSuccess)
		body = JSON.load(response.body)
		Hegesmart.config.coinmarketcap.watch_currencies.each do |currencie|
			c = body['data'].find{|c| c['slug'] == currencie}
			if !c.nil?
				rec = {name: c['name'], symbol: c['symbol'], 
					  slug: c['slug'], last_updated: c['last_updated'],
					  price: c['quote']['EUR']['price']}
				Crypto.insert(rec)
			end
		end
		true 

	end

end