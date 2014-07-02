# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "snoopy_afip"
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Leandro Marcucci"]
  s.date = "2011-03-21"
  s.description = "Adaptador para el Web Service de Facturacion Electronica de AFIP"
  s.email = "leanucci@vurbia.com"
  s.extra_rdoc_files = ["LICENSE.txt", "README.textile"]
  s.files = [".document", "CHANGELOG", "Gemfile", "Gemfile.lock", "LICENSE.txt", "README.textile", "Rakefile", "VERSION", "autotest/discover.rb", "snoopy_afip.gemspec", "lib/snoopy_afip.rb", "lib/snoopy_afip/auth_data.rb", "lib/snoopy_afip/authorizer.rb", "lib/snoopy_afip/bill.rb", "lib/snoopy_afip/constants.rb", "lib/snoopy_afip/core_ext/float.rb", "lib/snoopy_afip/core_ext/hash.rb", "lib/snoopy_afip/core_ext/string.rb", "lib/snoopy_afip/version.rb", "spec/snoopy_afip/auth_data_spec.rb", "spec/snoopy_afip/authorizer_spec.rb", "spec/snoopy_afip/bill_spec.rb", "spec/spec_helper.rb", "wsaa-client.sh"]
  s.homepage = "http://github.com/Vurbia/Bravo"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.25"
  s.summary = "Adaptador AFIP wsfe."
  s.test_files = ["spec/snoopy_afip/auth_data_spec.rb", "spec/snoopy_afip/authorizer_spec.rb", "spec/snoopy_afip/bill_spec.rb", "spec/spec_helper.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<savon>, ["= 2.4.0"])
      s.add_development_dependency(%q<ruby-debug>, [">= 0"])
      s.add_development_dependency(%q<ruby-debug-base19>, ["= 0.11.24"])
      s.add_development_dependency(%q<ruby-debug19>, ["= 0.11.6"])
      s.add_development_dependency(%q<rspec>, ["~> 2.4.0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.5.1"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
      s.add_runtime_dependency(%q<nokogiri>, ["= 1.5.0"])
      s.add_runtime_dependency(%q<wasabi>, ["~> 3.2.3"])
      s.add_runtime_dependency(%q<akami>, ["~> 1.1"])
      s.add_runtime_dependency(%q<nori>, ["~> 2.3.0"])
    else
      s.add_dependency(%q<savon>, ["= 2.4.0"])
      s.add_dependency(%q<ruby-debug>, [">= 0"])
      s.add_dependency(%q<ruby-debug-base19>, ["= 0.11.24"])
      s.add_dependency(%q<ruby-debug19>, ["= 0.11.6"])
      s.add_dependency(%q<rspec>, ["~> 2.4.0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.5.1"])
      s.add_dependency(%q<rcov>, [">= 0"])
      s.add_dependency(%q<nokogiri>, ["= 1.5.0"])
      s.add_dependency(%q<wasabi>, ["~> 3.2.3"])
      s.add_dependency(%q<akami>, ["~> 1.1"])
      s.add_dependency(%q<nori>, ["~> 2.3.0"])
    end
  else
    s.add_dependency(%q<savon>, ["= 2.4.0"])
    s.add_dependency(%q<ruby-debug>, [">= 0"])
    s.add_dependency(%q<ruby-debug-base19>, ["= 0.11.24"])
    s.add_dependency(%q<ruby-debug19>, ["= 0.11.6"])
    s.add_dependency(%q<rspec>, ["~> 2.4.0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.5.1"])
    s.add_dependency(%q<rcov>, [">= 0"])
    s.add_dependency(%q<nokogiri>, ["= 1.5.0"])
    s.add_dependency(%q<wasabi>, ["~> 3.2.3"])
    s.add_dependency(%q<akami>, ["~> 1.1"])
    s.add_dependency(%q<nori>, ["~> 2.3.0"])
  end
end
