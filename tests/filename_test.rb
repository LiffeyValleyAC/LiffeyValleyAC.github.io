require_relative "test_helper"

class FilenameTest < Blog::Test
  def test_valid_filename
    posts.each do |filename|
      assert filename =~ /^_posts\//, "New posts should be in the `_posts/` folder"
      assert filename =~ /^_posts\/\d{4}-\d{2}-\d{2}/, "Post filenames should start with a date in the format of YYYY-MM-DD"
      assert filename =~ /\.md$/, "New posts should have a `.md` extension"
      assert filename =~ /^_posts\/\d{4}-\d{2}-\d{2}-[a-z0-9\-]+\.md/i, "New posts should be named in the form of YYYY-MM-DD-filename.md"
    end
    races.each do |filename|
      assert filename =~ /^_races\//, "New races should be in the `_races/` folder"
      assert filename =~ /^_races\/\d{4}-\d{2}-\d{2}/, "Post filenames should start with a date in the format of YYYY-MM-DD"
      assert filename =~ /\.md$/, "New races should have a `.md` extension"
      assert filename =~ /^_races\/\d{4}-\d{2}-\d{2}-[a-z0-9\-]+\.md/i, "New races should be named in the form of YYYY-MM-DD-filename.md"
    end
  end
end
