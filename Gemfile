source 'https://rubygems.org'

# Specify your gem's dependencies in arqivarius.gemspec
gemspec

#ruby '2.1.0', engine: "rbx", engine_version: "2.2.3"

platforms :rbx do
  gem 'json'
  gem 'racc'
  gem 'rubysl-base64'
  gem 'rubysl-ipaddr'
  gem 'rubysl-openssl'
  gem 'rubysl-singleton'
  gem 'rubysl-xmlrpc'

  group :development do
    gem 'rubysl-irb'
    gem 'rubinius-compiler'
    gem 'rubinius-debugger'
  end
end
