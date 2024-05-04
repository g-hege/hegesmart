class SheetApi

	def self.sheet_tab
		[	
			{sheet_title: 'energy 30 days', 			sql_view: 'EnergyLast30Days'},
			{sheet_title: 'spotty 30 days', 			sql_view: 'EnergySpottyLast30Days'},
			{sheet_title: 'monthly spotty', 			sql_view: 'EnergyMonthlySpotty'},
			{sheet_title: 'monthly consumption', 	sql_view: 'EnergyMonthlyStatistik'},
			{sheet_title: 'yearly consumption', 	sql_view: 'EnergyYearlyStatistik'}
		]
	end

	def self.update_google_sheet
		sheet_tab.each {|sheet| update_sheet(sheet[:sheet_title], sheet[:sql_view])}
		puts "update google sheet done!"
	end

	def self.colmap
		('A'..'Z').map{|i|i}
	end

	def self.annual_accounts
		[
			{year: 2015, wienstrom: 9868},
			{year: 2016, wienstrom: 9580},
			{year: 2017, wienstrom: 8531},
			{year: 2018, wienstrom: 8424},
			{year: 2019, wienstrom: 8167},
			{year: 2020, wienstrom: 8029},
			{year: 2021, wienstrom: 7260},
		]
	end

	def self.update_sheet(sheet_title, sql_view)

		columns = eval(sql_view).first.columns
		data = [columns.map{|c| c.to_s}]

		if sheet_title == 'yearly consumption'
			annual_accounts.each do |j|
				data << [ j[:year], j[:wienstrom], 0,0,0,0,0,0,0,0,0,0 ]
			end
		end
		eval(sql_view).each do |r|
			data << columns.map {|c| (r[c].kind_of? BigDecimal) ? r[c].to_f : r[c]}
		end 

		data[8][1] = data[8][1] + 3074 if sheet_title == 'yearly consumption' # fix year 2022


    	range_name = "#{sheet_title}!A1:L#{data.size}"
		col_range = Google::Apis::SheetsV4::ValueRange.new(values: data)
		Hegesmart.sheet_service.update_spreadsheet_value(Hegesmart.config.sheetid, range_name, col_range , value_input_option:'USER_ENTERED')
		sumrow = ['Kwh']
		for i in 2..columns.count
			sumrow << "=SUM(#{SheetApi.colmap[i-1]}2:#{SheetApi.colmap[i-1]}#{data.size})"
		end
		rows = []
		rows << sumrow
		for i in (data.size+1)..(data.size+10)
			rows << columns.count.times.map {""}
		end
	  	col_range = Google::Apis::SheetsV4::ValueRange.new(values: rows)
    	range_name = "#{sheet_title}!A#{data.size + 1}:#{SheetApi.colmap[columns.count-1]}"
#    	range_name = "#{sheet_title}!A#{data.size + 1}:#{SheetApi.colmap[columns.count-1]}#{data.size + 3}"
		Hegesmart.sheet_service.update_spreadsheet_value(Hegesmart.config.sheetid, range_name, col_range, value_input_option:'USER_ENTERED' )

	end

end
