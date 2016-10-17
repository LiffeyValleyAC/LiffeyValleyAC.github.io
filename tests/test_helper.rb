require "fileutils"

require "rubygems"
require "bundler/setup"
require "minitest/autorun"

module Blog
  class Test < MiniTest::Test
    # All the posts we're interested in checking. This means we're looking at
    # files that have changed on this particular branch we're on.
    #
    # Returns an Array of String filenames.
    def posts
      posts = `git diff --name-only --diff-filter=ACMRTUXB origin/master... | grep _posts`.split("\n")

      posts
    end

    def races
      races = `git diff --name-only --diff-filter=ACMRTUXB origin/master... | grep _races`.split("\n")

      races
    end
  end
end
