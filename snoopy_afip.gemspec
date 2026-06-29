# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'snoopy_afip/version'

Gem::Specification.new do |s|
  s.name = "snoopy_afip"
  s.version = Snoopy::VERSION

  s.required_ruby_version = ">= 2.5"
  s.authors = ["g.edera"]
  s.description = "Adaptador para Web Service de Facturación Electrónica Argentina (AFIP)"
  s.email = "gab.edera@gmail.com"
  s.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.homepage = "https://github.com/gedera/snoopy_afip"
  s.licenses = "MIT"
  s.require_paths = ["lib"]
  # s.rubygems_version = "1.8.25"
  s.summary = "Adaptador AFIP wsfe."
  s.test_files = Dir["spec/**/*"]

  s.add_dependency 'savon', '~> 2.12.1'

  s.add_development_dependency 'rspec', '~> 3.13'
  s.add_development_dependency 'activesupport' # Bill#valid? usa blank?/present?
end
