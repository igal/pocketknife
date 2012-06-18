# encoding: utf-8

task :default => :spec

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
  gem.summary = %Q{pocketknife is a devops tool for managing computers running chef-solo, powered by Opscode Chef.}
  gem.description = <<-HERE
pocketknife is a devops tool for managing computers running chef-solo, powered by Opscode Chef.

Using pocketknife, you create a project that describes the configuration of your computers and then deploy it to bring them to their intended state.

With pocketknife, you don't need to setup or manage a specialized chef-server node or rely on an unreliable network connection to a distant hosted service whose security you don't control, deal with managing chef's security keys, or deal with manually synchronizing data with the chef-server datastore.

With pocketknife, all of your cookbooks, roles and nodes are stored in easy-to-use files that you can edit, share, backup and version control with tools you already have.
  HERE
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

desc "Run coverage report using simplecov."
task :simplecov do
  ENV['SIMPLECOV'] = 'true'
  Rake::Task['spec'].invoke
end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

def rcov(options=[])
  # None of the official ways to invoke Rcov work right now. Sigh.
  cmd = "rcov --exclude osx\/objc,gems\/,spec\/,features\/,lib/shellwords.rb,lib/pocketknife/version.rb #{[options].flatten} $(which rspec) spec/*_spec.rb 2>&1"
  puts cmd
  output = `#{cmd}`
  puts output
  return output
end

RCOV_DATA = 'coverage/rcov.data'
RCOV_LOG = 'coverage/rcov.txt'

namespace :rcov do
  desc "Save rcov information for use with rcov:diff"
  task :save do
    rcov "--save=#{RCOV_DATA}"
  end

  desc "Generate report of what code changed since last rcov:save"
  task :diff do
    output = rcov "--no-color --text-coverage-diff=#{RCOV_DATA}"
    File.open(RCOV_LOG, 'w+') do |h|
      h.write output
    end
    puts "\nSaved coverage report to: #{RCOV_LOG}"
  end
end

desc  "Run all specs with rcov"
task :rcov do
  rcov
end

require 'yard'
YARD::Rake::YardocTask.new

desc "List undocumented code"
task :undoc do
  system "yardoc --list-undoc | grep -v 'Unrecognized/invalid option'"
end
