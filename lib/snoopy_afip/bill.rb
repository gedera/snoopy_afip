# coding: utf-8
module Snoopy
  class Bill
    include AuthData

    attr_reader :base_imp, :total

    attr_accessor :total_net, :document_num, :document_type, :concept, :currency, :result,
                  :due_date, :aliciva_id, :body, :response, :cbte_asoc_num, :cae, :service_date_to,
                  :number, :alicivas, :pkey, :cert, :cuit, :sale_point, :auth, :service_date_from,
                  :due_date_cae, :voucher_date, :process_date, :imp_iva, :cbte_asoc_sale_point,
                  :receiver_iva_cond, :issuer_iva_cond, :observations, :events, :errors, :backtrace

    def initialize(attrs={})
      @pkey                    = attrs[:pkey]
      @cert                    = attrs[:cert]
      @cuit                    = attrs[:cuit]
      @errors                  = []
      @events                  = []
      @concept                 = attrs[:concept] || Snoopy.default_concept
      @imp_iva                 = attrs[:imp_iva] # Monto total de impuestos
      @currency                = attrs[:currency] || Snoopy.default_currency
      @alicivas                = attrs[:alicivas]
      @response                = nil
      @total_net               = attrs[:net] || 0
      @backtrace               = ''
      @sale_point              = attrs[:sale_point]
      @observations            = []
      @document_num            = attrs[:doc_num]
      @cbte_asoc_num           = attrs[:cbte_asoc_num] # Esto es el numero de factura para la nota de credito
      @document_type           = attrs[:document_type] || Snoopy.default_document_type
      @issuer_iva_cond         = attrs[:own_iva_cond]
      @service_date_to         = attrs[:service_date_to]
      @service_date_from       = attrs[:service_date_from]
      @receiver_iva_cond       = attrs[:iva_cond]
      @cbte_asoc_to_sale_point = attrs[:cbte_asoc_to_sale_point] # Esto es el punto de venta de la factura para la nota de credito
    end

    def exchange_rate
      return 1 if currency == :peso
      response = client.fe_param_get_cotizacion do |soap|
        soap.namespaces["xmlns"] = "http://ar.gov.afip.dif.FEV1/"
        soap.body = body.merge!({"MonId" => Snoopy::CURRENCY[currency][:code]})
      end
      response.to_hash[:fe_param_get_cotizacion_response][:fe_param_get_cotizacion_result][:result_get][:mon_cotiz].to_f
    end

    def total
      @total = total_net.zero? ? 0 : (total_net + iva_sum).round(2)
    end

    def iva_sum
      @iva_sum = alicivas.collect{|aliciva| if aliciva.has_key?('amount'); aliciva['amount'].to_f; else aliciva[:amount].to_f end }.sum.to_f.round_with_precision(2)
    end

    def cbte_type
      Snoopy::BILL_TYPE[receiver_iva_cond.to_sym] || raise(NullOrInvalidAttribute.new, "Please choose a valid document type.")
    end

    def client
      Savon.client( :wsdl => Snoopy.service_url,
                    :ssl_cert_key_file => pkey,
                    :ssl_cert_file => cert,
                    :ssl_version => :TLSv1,
                    :read_timeout => 90,
                    :open_timeout => 90,
                    :headers => { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" },
                    :pretty_print_xml => true,
                    :namespaces => {"xmlns" => "http://ar.gov.afip.dif.FEV1/"} )
    end

    def set_bill_number!
      resp = client.call( :fe_comp_ultimo_autorizado,
                          :message => { "Auth" => generate_auth_file, "PtoVta" => sale_point, "CbteTipo" => cbte_type })

      resp_errors = resp.hash[:envelope][:body][:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
      resp_errors.each_value { |value| @errors << "Código #{value[:code]}: #{value[:msg]}" } unless resp_errors.nil?
      @number = resp.to_hash[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 if @errors.empty?
    end

    def build_header
      { "CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => sale_point }
    end

    def build_body_request
      # today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')
      today = Date.today.strftime('%Y%m%d')

      fecaereq = {"FeCAEReq" => {
                    "FeCabReq" => build_header,
                    "FeDetReq" => {
                      "FECAEDetRequest" => {
                        "Concepto"    => Snoopy::CONCEPTS[concept],
                        "DocTipo"     => Snoopy::DOCUMENTS[document_type],
                        "CbteFch"     => today,
                        "ImpTotConc"  => 0.00,
                        "MonId"       => Snoopy::CURRENCY[currency][:code],
                        "MonCotiz"    => exchange_rate,
                        "ImpOpEx"     => 0.00,
                        "ImpTrib"     => 0.00 }}}}

      unless issuer_iva_cond.to_sym == :responsable_monotributo
        _alicivas = alicivas.collect do |aliciva|
          id = if aliciva.has_key?('id'); aliciva['id']; else aliciva[:id]; end
          importe = if aliciva.has_key?('importe'); aliciva['importe']; else aliciva[:importe]; end
          base_imp = if aliciva.has_key?('taxeable_base'); aliciva['taxeable_base']; else aliciva[:taxeable_base]; end
          { "Id" => Snoopy::ALIC_IVA[id], "BaseImp" => base_imp, "Importe" => importe }
        end
        fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]["Iva"] = { "AlicIva" => _alicivas }
      end

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      detail["DocNro"]    = document_num
      detail["ImpNeto"]   = total_net.to_f
      detail["ImpIVA"]    = iva_sum
      detail["ImpTotal"]  = total

      detail["CbteDesde"] = detail["CbteHasta"] = number

      unless concept == "Productos"
        detail.merge!({ "FchServDesde" => service_date_from || today,
                        "FchServHasta" => service_date_to || today,
                        "FchVtoPago"   => due_date       || today})
      end

      if self.receiver_iva_cond.to_s.include?("nota_credito")
        detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro"    => cbte_asoc_num,
                                                      "PtoVta" => cbte_asoc_to_sale_point,
                                                      "Tipo"   => cbte_type }}})
      end

      @body = { "Auth" => generate_auth_file }.merge!(fecaereq)
    end

    def cae_request
      begin
        set_bill_number!
        if @errors.empty?
          build_body_request
          @response = client.call( :fecae_solicitar, :message => body ).body
          parse_fecae_solicitar_response
        end
      rescue => e #Curl::Err::GotNothingError, Curl::Err::TimeoutError
        @errors = e.message
        @backtrace = e.backtrace
      end
      !@response.nil?
    end

    def approved?; @result == 'A'; end
    def rejected?; @result == 'R'; end
    def partial_approved?; @result == 'P'; end

    # Para probar que la conexion con afip es correcta, si este metodo devuelve true, es posible realizar cualquier consulta al ws de la AFIP.
    def connection_valid?
      begin
        result = client.call(:fe_dummy).body[:fe_dummy_response][:fe_dummy_result]
        @observations << "app_server: #{result[:app_server]}, db_server: #{result[:db_server]}, auth_server: #{result[:auth_server]}"
        result[:app_server] == "OK" and result[:db_server] == "OK" and result[:auth_server] == "OK"
      rescue => e
        @errors << e.message
        @backtrace = e.backtrace
        false
      end
    end

    def parse_observations(fecae_observations)
      begin
        fecae_observations.each_value do |obs|
          [obs].flatten.each { |ob| @observations << "Código #{ob[:code]}: #{ob[:msg]}" }
        end
      rescue
        @observations << "Ocurrió un error al parsear las observaciones de AFIP"
      end
    end

    def parse_errors(fecae_errors)
      begin
        fecae_errors.each_value do |errores|
          [errores].flatten.each { |error| @errors << "Código #{error[:code]}: #{error[:msg]}" }
        end
      rescue
        @errors << "Ocurrió un error al parsear los errores de AFIP"
      end
    end

    def parse_events(fecae_events)
      begin
        fecae_events.each_value do |events|
          [events].flatten.each { |event| @events << "Código #{event[:code]}: #{event[:msg]}" }
        end
      rescue
        @events << "Ocurrió un error al parsear los eventos de AFIP"
      end
    end

    def parse_fecae_solicitar_response
      fecae_response = @response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_det_resp][:fecae_det_response] rescue {}
      fe_cab_resp    = @response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_cab_resp] rescue {}
      fecae_result   = @response[:fecae_solicitar_response][:fecae_solicitar_result] rescue {}

      @cae          = fecae_response[:cae]
      @number       = fecae_response[:cbte_desde]
      @result       = fecae_response[:resultado]
      @due_date_cae = fecae_response[:cae_fch_vto]
      @voucher_date = fecae_response[:cbte_fch]
      @process_date = fe_cab_resp[:fch_proceso]

      parse_observations(fecae_response.delete(:observaciones)) if fecae_response.has_key? :observaciones
      parse_errors(fecae_result[:errors])                       if fecae_result.has_key? :errors
      parse_events(fecae_result[:events])                       if fecae_result.has_key? :events
    end

    def parse_fe_comp_consultar_response
      result_get               = @response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:result_get]
      fe_comp_consultar_result = @response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result]

      unless result_get.nil?
        @cae               = result_get[:cod_autorizacion]
        @imp_iva           = result_get[:imp_iva]
        @number            = result_get[:cbte_desde]
        @result            = result_get[:resultado]
        @document_num      = result_get[:doc_numero]
        @process_date      = result_get[:fch_proceso]
        @due_date_cae      = result_get[:fch_vto]
        @voucher_date      = result_get[:cbte_fch]
        @service_date_to   = result_get[:fch_serv_hasta]
        @service_date_from = result_get[:fch_serv_desde]
        parse_events(result_get[:observaciones]) if result_get.has_key? :observaciones
      end

      self.parse_events(fe_comp_consultar_result[:errors]) if fe_comp_consultar_result and fe_comp_consultar_result.has_key? :errors
      self.parse_events(fe_comp_consultar_result[:events]) if fe_comp_consultar_result and fe_comp_consultar_result.has_key? :events
    end

    def self.bill_request(number, attrs={})
      bill = new(attrs)
      begin
        bill.response = bill.client.call( :fe_comp_consultar,
                                          :message => {"Auth" => bill.generate_auth_file,
                                                       "FeCompConsReq" => {"CbteTipo" => bill.cbte_type, "PtoVta" => bill.sale_point, "CbteNro" => number.to_s}})
        bill.parse_fe_comp_consultar_response
      rescue => e
        bill.errors << e.message
        bill.backtrace = e.backtrace
      end
      bill
    end

  end
end
