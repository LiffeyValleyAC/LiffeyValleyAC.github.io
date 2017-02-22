require_relative "test_helper"

class RaceResultsTest < Blog::Test
  def has_time_field?(result)
    result.has_key?('time') || result.has_key?('finish_time')
  end

  def time_field(result)
    field = false
    if result.has_key?('time')
      field = 'time'
    elsif result.has_key?('finish_time')
      field = 'finish_time'
    end
    return field
  end

  def test_correct_field_name
    finish_time = []

    races.each do |filename|
      yaml = YAML.load_file(filename)
      if yaml.has_key?('results')
        yaml['results'].each do |result|
          finish_time << filename unless has_time_field?(result)
        end
      end
    end

    assert finish_time.empty?,
      "You need either a `time` or `finish_time` field in the results section of these files:\n" +
      finish_time.uniq.map { |file| "* #{file}" }.join("\n")
  end

  def test_time_formatting
    offences = []
    regex = /\d+m \d+s/

    races.each do |filename|
      yaml = YAML.load_file(filename)
      if yaml.has_key?('results')
        yaml['results'].each do |result|
          next unless has_time_field?(result)
          field = time_field(result)
          offences << filename unless result[field].to_s.match(regex)
        end
      end
    end

    assert offences.empty?,
      "The results times are in the wrong format, they should be 'XXm XXs'. These are the offending files:\n" +
      offences.uniq.map { |file| "* #{file}" }.join("\n")
  end
end
