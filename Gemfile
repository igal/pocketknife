source "http://rubygems.org"

gem "archive-tar-minitar", "~> 0.5.0"
gem "rye", "~> 0.9.0"

group :development do
  gem "rake"

  gem "bluecloth", "~> 2.2.0"
  gem "rspec", "~> 2.7.0"
  gem "yard", "~> 0.7.0"
  gem "jeweler", "~> 1.6.0"

  platform :mri_18 do
    gem 'rcov', :require => false
    gem 'ruby-debug'
  end

  platform :mri_19 do
    gem 'simplecov', :require => false
    gem 'ruby-debug19'
  end
end
