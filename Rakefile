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

load './lib/pocketknife/version.rb'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.version = Pocketknife::Version::STRING
  gem.name = "pocketknife"
  gem.homepage = "http://github.com/igal/pocketknife"
  gem.license = "MIT"
  gem.summary = %Q{pocketknife is a tool for managing chef-solo nodes.}
  gem.description = %Q{pocketknife is a tool for managing chef-solo nodes.}
  gem.email = "igal+pocketknife@pragmaticraft.com"
  gem.authors = ["Igal Koshevoy"]
  gem.executables += %w[
    pocketknife
  ]
  gem.files += %w[
    Gemfile
    LICENSE.txt
    README.md
    Rakefile
    lib/*
    spec/*
  ]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
