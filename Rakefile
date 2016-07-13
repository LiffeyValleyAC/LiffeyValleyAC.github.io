require 'html-proofer'
require 'rake'
require 'rake/testtask'

task :test do
  sh "bundle exec jekyll build"
  HTMLProofer.check_directory("./_site", {:disable_external => true}).run
end

Rake::TestTask.new(:runtest) do |test|
    test.libs << "tests"
    test.pattern = 'tests/**/*_test.rb'
end
