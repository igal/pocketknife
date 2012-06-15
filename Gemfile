source 'http://rubygems.org'

gem 'archive-tar-minitar', '~> 0.5.0'
gem 'rye', '~> 0.9.0'

group :development do
  gem 'rake'

  gem 'bluecloth', '~> 2.2.0'
  gem 'rspec', '~> 2.10.0'
  gem 'yard', '~> 0.8.0'
  gem 'jeweler', '~> 1.8.0'

  # OPTIONAL LIBRARIES: These libraries upset travis-ci and may cause Ruby or
  # RVM to hang, so only use them when needed.
  if ENV['DEBUGGER']
    platform :mri_18 do
      gem 'rcov', :require => false
      gem 'ruby-debug'
    end

    platform :mri_19 do
      gem 'simplecov', :require => false
      gem 'debugger-ruby_core_source'
      gem 'debugger'
    end
  end
end
