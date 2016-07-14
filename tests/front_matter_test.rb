require_relative "test_helper"
require "yaml"

class FrontMatterTest < Blog::Test
  def test_valid_front_matter
    posts.each do |filename|
      yaml = YAML.load_file(filename)
      assert yaml[title].exist?
    end
  end
end
