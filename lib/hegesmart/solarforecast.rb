class SolarForecast
# https://toolkit.solcast.com.au/home-pv-system/6f2d-1745-f605-e260/detail
  def self.update 
    puts "#{DateTime.now.strftime('%Y-%m-%d %M:%H')} SolarForecast update"
    uri = URI(Hegesmart.config.solcast.uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req =  Net::HTTP::Get.new(uri.request_uri)
    req['Authorization'] = "Bearer #{Hegesmart.config.solcast.apikey}"
    req['Content-type']  = 'application/json'
    req['Accept']        = 'application/json'
    response = http.request(req)
    return nil if !response.is_a?(Net::HTTPSuccess)
    response.is_a?(Net::HTTPSuccess)
    body = JSON.load(response.body)

    SolarForecast.unrestrict_primary_key
    body['forecasts'].each do |f|
      SolarForecast.update_or_create({period_end: Time.parse(f['period_end']) + 60*60*2 }, {pv_estimate: f['pv_estimate'] / 10, pv_estimate10: f['pv_estimate10']/10, pv_estimate90: f['pv_estimate90']/10})
    end;
    true
  end


end
