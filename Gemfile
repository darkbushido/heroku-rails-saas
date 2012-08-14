source :rubygems
gemspec

gem "rake"
group :development, :test do
   gem "rdoc", '~> 3.12'
end

group :test do
  gem "ruby-debug", :platforms => :mri_18
  gem "ruby-debug19", :platforms => :mri_19
  
  gem "rspec"
end
