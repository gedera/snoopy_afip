# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'snoopy_afip/version'

Gem::Specification.new do |s|
  s.name = "snoopy_afip"
  s.version = Snoopy::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["g.edera"]
  s.date = "2016-09-12"
  s.description = "Adaptador para Web Service de Facturación Electrónica Argentina (AFIP)"
  s.email = ["gab.edera@gmail.com"]
  s.extra_rdoc_files = ["LICENSE.txt", "README.textile"]
  s.files = [".document", "CHANGELOG", "Gemfile", "Gemfile.lock", "LICENSE.txt", "README.textile", "Rakefile", "VERSION", "autotest/discover.rb", "snoopy_afip.gemspec", "lib/snoopy_afip.rb", "lib/snoopy_afip/authentication_adapter.rb", "lib/snoopy_afip/authorize_adapter.rb", "lib/snoopy_afip/bill.rb", "lib/snoopy_afip/client.rb", "lib/snoopy_afip/constants.rb", "lib/snoopy_afip/core_ext/float.rb", "lib/snoopy_afip/core_ext/hash.rb", "lib/snoopy_afip/core_ext/string.rb", "lib/snoopy_afip/exceptions.rb", "lib/snoopy_afip/version.rb", "spec/snoopy_afip/authorizer_spec.rb", "spec/snoopy_afip/bill_spec.rb", "spec/spec_helper.rb", "wsaa-client.sh"]
  s.homepage = "https://github.com/gedera/snoopy_afip"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  # s.rubygems_version = "1.8.25"
  s.summary = "Adaptador AFIP wsfe."
  s.test_files = ["spec/snoopy_afip/authorizer_spec.rb", "spec/snoopy_afip/bill_spec.rb", "spec/spec_helper.rb"]

  s.add_runtime_dependency('savon', ["~> 2.4"])
  s.add_runtime_dependency('nokogiri', ["~> 1.6"])
  s.add_runtime_dependency('wasabi', ["~> 3.2"])
  s.add_runtime_dependency('akami', ["~> 1.2"])
  s.add_runtime_dependency('nori', ["~> 2.3"])
end
