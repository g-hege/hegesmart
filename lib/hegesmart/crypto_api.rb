class Crypto_api

	def self.update 

		uri = URI.parse("#{Hegesmart.config.coinmarketcap.url}/v1/cryptocurrency/listings/latest");
		params = {'start' => 1,'limit' => 500, 'convert' => 'EUR'}
		uri.query = URI.encode_www_form(params)

		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = uri.scheme == 'https'
		req =  Net::HTTP::Get.new(uri.request_uri);
		req['Accept']        = 'application/json'
		req['X-CMC_PRO_API_KEY'] = Hegesmart.config.coinmarketcap.auth_key
		
		response = http.request(req)

		if response.is_a?(Net::HTTPUnauthorized)
			puts "HTTPUnauthorized"
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