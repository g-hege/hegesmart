#!/usr/bin/env ruby

require_relative '../config/boot.rb' 

Mqtt_api.marketprice
ShellyApi.update_market_price

