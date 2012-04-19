# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "has-activity"
  gem.homepage = "http://github.com/cdunn/has_activity"
  gem.license = "MIT"
  gem.summary = "A simple way to grab recent activity on a given model grouped by hour, day, week or month (time series)."
  gem.description = "A simple way to grab recent activity on a given model grouped by hour, day, week or month (time series). Supports \"padding\" for intervals without activity."
  gem.email = "cary.dunn@gmail.com"
  gem.authors = ["Cary Dunn"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end
