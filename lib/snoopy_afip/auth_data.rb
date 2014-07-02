#require 'active_support/time'

module Snoopy
  class AuthData

    class << self
      def fetch
        unless File.exists?(Snoopy.pkey)
          raise "Archivo de llave privada no encontrado en #{Snoopy.pkey}"
        end

        unless File.exists?(Snoopy.cert)
          raise "Archivo certificado no encontrado en #{Snoopy.cert}"
        end

        todays_datafile = "/tmp/bravo_#{Time.new.strftime('%d_%m_%Y')}.yml"
        opts = "-u #{Snoopy.auth_url}"
        opts += " -k #{Snoopy.pkey}"
        opts += " -c #{Snoopy.cert}"
        opts += " -i #{Snoopy.cuit}"

        unless File.exists?(todays_datafile)
          %x(#{File.dirname(__FILE__)}/../../wsaa-client.sh #{opts})
        end

        @data = YAML.load_file(todays_datafile).each do |k, v|
          Snoopy.const_set(k.to_s.upcase, v) unless Snoopy.const_defined?(k.to_s.upcase)
        end
      end
    end
  end
end
