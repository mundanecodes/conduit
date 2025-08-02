require_relative "lib/conduit/version"

Gem::Specification.new do |spec|
  spec.name = "conduit"
  spec.version = Conduit::VERSION
  spec.authors = ["Charles Chuck"]
  spec.email = ["chalcchuck@email.com"]
  spec.homepage = "https://github.com/chalchuck/conduit"
  spec.summary = "Lightning-fast USSD flow engine for Rails"
  spec.description = "Build USSD applications with an expressive DSL. Redis-backed sessions, AfricasTalking integration, built for the 60-120 second constraint."
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.4.0"

  spec.add_dependency "rails", ">= 8.0.2"
  spec.add_dependency "redis", ">= 5.0"
  spec.add_dependency "connection_pool", "~> 2.4"
  spec.add_dependency "hiredis-client", ">= 0.22"

  spec.add_development_dependency "standard"
  spec.add_development_dependency "rubocop-rails-omakase"
  spec.add_development_dependency "rspec-rails", "~> 8.0"
  spec.add_development_dependency "fakeredis"
  spec.add_development_dependency "pry-rails"
end
