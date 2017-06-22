# coding: utf-8
module Snoopy
  class Authorizer
    attr_reader :pkey, :cert, :tra, :cms, :request, :response

    def initialize(pkey, cert)
      @pkey = pkey
      @cert = cert
    end

    def call
      @response = %x(echo "#{build_request}" | curl -k -H 'Content-Type: application/soap+xml; action=""' -d @- #{Snoopy.auth_url})
    end

    def build_request
      @request = <<-HEREDOC
        <?xml version="1.0" encoding="UTF-8"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://wsaa.view.sua.dvadac.desein.afip.gov">
          <SOAP-ENV:Body>
            <ns1:loginCms>
              <ns1:in0>
                #{build_cms}
              </ns1:in0>
            </ns1:loginCms>
          </SOAP-ENV:Body>
        </SOAP-ENV:Envelope>
      HEREDOC
      #puts @request
    end

    def build_cms
      openssl = %x(which openssl).chomp
      @cms = %x(echo "#{build_tra}" | #{openssl} cms -sign -in /dev/stdin -signer #{@cert} -inkey #{@pkey} -nodetach -outform der | #{openssl} base64 -e)
    end

    def build_tra
      from = Date.today.to_time # FROM = $(date "+%Y-%m-%dT00:00:00-03:00")
      to = Date.today.to_time.strftime("%Y-%m-%dT23:59:59%z") # TO = $(date "+%Y-%m-%dT23:59:59-03:00")
	    id = DateTime.now.strftime('%Q') # ID = $(date "+%s")
      @tra = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><loginTicketRequest version=\"1.0\"><header><uniqueId>#{id}</uniqueId><generationTime>#{from}</generationTime><expirationTime>#{to}</expirationTime></header><service>wsfe</service></loginTicketRequest>"
      # @tra = <<-HEREDOC
      # <?xml version="1.0" encoding="UTF-8"?>
      #   <loginTicketRequest version="1.0">
      #   <header>
      #     <uniqueId>#{id}</uniqueId>
      #     <generationTime>#{from}</generationTime>
      #     <expirationTime>#{to}</expirationTime>
      #   </header>
      #   <service>wsfe</service>
      #   </loginTicketRequest>
      # HEREDOC
    end

    def client_savon
      Savon.client( :wsdl              => "https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl",
                    # :headers           => { "Content-Type" => "application/soap+xml", "action" => "" },
                    # :namespaces        => {"xmlns" => "https://wsaa.afip.gov.ar/ws/services/LoginCms"},
                    :ssl_version       => :SSLv3,
                    # :convert_request_keys_to => :camelcase,
                    :pretty_print_xml  => true )
    end

    def login_ticket_request
      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.loginTicketRequest('version' => '1.0') {
          xml.header {
            xml.uniqueId "12314213"
            xml.generationTime "2017-06-21T00:00:00-03:00"
            xml.expirationTime "2017-06-21T23:59:59-03:00"
          }
        }
      end

      tra = Tempfile.new()
      File.open(tra.path, 'w') { |file| file.write(builder.to_xml) }

      path1 = "/home/gabriel/src/wispro/microservices/argentina_invoice_service/certs/testing_pkey"
      path2 = "/home/gabriel/src/wispro/microservices/argentina_invoice_service/certs/testing_cert.crt"

      key = OpenSSL::PKey::RSA.new(File.read(path1)) # key = OpenSSL::PKey::read File.read(@key)
      crt = OpenSSL::X509::Certificate.new(File.read(path2))
      pkcs7 = OpenSSL::PKCS7::sign(crt, key, File.read(tra.path))
      hola = pkcs7.to_pem.lines.to_a[1..-2].join # Base64.encode64(pkcs7.to_pem) # Codifica

      pepe = Tempfile.new("base64")
      File.open(pepe.path, 'w') { |file| file.write(Base64.encode64(pkcs7.to_pem)) }

      pepe = Tempfile.new("chupala")
      File.open(pepe.path, 'w') { |file| file.write(hola) }

      @client_savon.call :login_cms, in0: File.read(hola)
    end
  end
end


builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
  xml.loginTicketRequest('version' => '1.0') {
    xml.header {
      xml.uniqueId "12314213"
      xml.generationTime "2017-06-21T00:00:00-03:00"
      xml.expirationTime "2017-06-21T23:59:59-03:00"
    }
  }
end

# tra = Tempfile.new()
# File.open(tra.path, 'w') { |file| file.write(builder.to_xml) }

# path1 = "/home/gabriel/src/wispro/microservices/argentina_invoice_service/certs/testing_pkey"
# path2 = "/home/gabriel/src/wispro/microservices/argentina_invoice_service/certs/testing_cert.crt"

# #key = OpenSSL::PKey::RSA.new(File.read(path1))
# key = OpenSSL::PKey::read File.read(path1)
# crt = OpenSSL::X509::Certificate.new(File.read(path2))
# # pkcs7 = OpenSSL::PKCS7::sign(crt, key, File.read(tra.path))
# pkcs7 = OpenSSL::PKCS7::sign(crt, key, builder.to_xml)
# hola = pkcs7.to_pem.lines.to_a[1..-2].join # Base64.encode64(pkcs7.to_pem) # Codifica

# pepe = Tempfile.new("base64")
# File.open(pepe.path, 'w') { |file| file.write(Base64.encode64(hola)) }

# pepe = Tempfile.new("chupala")
# File.open(pepe.path, 'w') { |file| file.write(hola) }

# "https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl"
# @client_savon = Savon.client( :wsdl              => "https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl",
#                               # :headers           => { "Content-Type" => "application/soap+xml", "action" => "" },
#                               # :namespaces        => {"xmlns" => "https://wsaa.afip.gov.ar/ws/services/LoginCms"},
#                               :ssl_version       => :SSLv3,
#                               # :convert_request_keys_to => :camelcase,
#                               :pretty_print_xml  => true )
# # puts hola
# #@client_savon.call :login_cms, message: {in0: hola}
# @client_savon.call :login_cms, message: {in0: Base64.encode64(hola)}
