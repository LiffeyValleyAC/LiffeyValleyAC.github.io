require "csv"
require "trollop"

@options = Trollop::options do
  opt :csv, "Race results .csv file", type: :string, default: ''
end

if @options[:csv].empty? || !File.exist?(@options[:csv])
  Trollop::die :csv, "must be set and exist"
end

filename = @options[:csv]

csv = CSV.foreach(filename, :headers => true, :header_converters => :symbol, :converters => :all)

pos = 1
puts "results:"
csv.each do |c|
  puts "  - place: #{c[:place]}"
  puts "    name: #{c[:name]}"
  puts "    club: #{c[:club]}"
  puts "    county: #{c[:subcat]}"
  puts "    time: #{c[:result]}"
  pos = pos + 1
end
