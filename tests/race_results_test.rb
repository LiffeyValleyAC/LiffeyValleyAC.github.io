require_relative "test_helper"

class RaceResultsTest < Blog::Test
  def test_correct_field_name
    finish_time = []

    races.each do |filename|
      yaml = YAML.load_file(filename)
      if yaml.has_key?('results')
        yaml['results'].each do |result|
          finish_time << filename unless result.has_key?('finish_time')
        end
      end
    end

    assert finish_time.empty?,
      "The `finish_time` field is missing from the results in these files:\n" +
      finish_time.uniq.map { |file| "* #{file}" }.join("\n")
  end

  def test_time_formatting
    offences = []
    regex = /\d+m \d+s/

    races.each do |filename|
      yaml = YAML.load_file(filename)
      if yaml.has_key?('results')
        yaml['results'].each do |result|
          next unless result.has_key?('finish_time')
          offences << filename unless result['finish_time'].to_s.match(regex)
        end
      end
    end

    assert offences.empty?,
      "The results times are in the wrong format, they should be 'XXm XXs'. These are the offending files:\n" +
      offences.uniq.map { |file| "* #{file}" }.join("\n")
  end
end
