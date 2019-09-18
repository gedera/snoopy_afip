module Snoopy
  class AuthorizeAdapter

    attr_accessor :bill, :cuit, :sign, :pkey, :cert, :token, :errors, :request, :response, :afip_errors, :afip_events, :afip_observations, :client

    def initialize(attrs)
      @bill              = attrs[:bill]
      @cuit              = attrs[:cuit]
      @sign              = attrs[:sign]
      @pkey              = attrs[:pkey]
      @cert              = attrs[:cert]
      @token             = attrs[:token]
      @errors            = {}
      @request           = nil
      @response          = nil
      @afip_errors       = {}
      @afip_events       = {}
      @afip_observations = {}
      @client            = Snoopy::Client.new(client_configuration)
    end

    def auth
      { "Token" => token, "Sign" => sign, "Cuit" => cuit }
    end

    def invoice_informed?
      return false unless bill.valid?

      build_body_comp_cons_request
      @response = client.call(:fe_comp_consultar, :message => @comp_cons_request)
      parse_fe_comp_consultar_response

      afip_errors.keys.empty?
    end

    def authorize!
      return false unless bill.valid?

      build_body_comp_cons_request
      @response = client.call(:fe_comp_consultar, :message => @comp_cons_request)
      parse_fe_comp_consultar_response

      if bill.number.nil? || afip_errors.keys.include?('602') # No esta informado ese numero
        @afip_errors = {}
        set_bill_number!
        build_body_request
        @response = client.call(:fecae_solicitar, :message => @request)
        parse_fecae_solicitar_response
      end

      !@response.nil?
    end

    def set_bill_number!
      message = { "Auth" => auth, "PtoVta" => bill.sale_point, "CbteTipo" => bill.cbte_type }
      resp = client.call( :fe_comp_ultimo_autorizado, :message =>  message )

      begin
        resp_errors = resp[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
        resp_errors.each_value { |value| errors[value[:code]] = value[:msg] } unless resp_errors.nil?
        bill.number = resp[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 if errors.empty?
        bill.number
      rescue => e
        raise Snoopy::Exception::AuthorizeAdapter::SetBillNumberParser.new(e.message, e.backtrace)
      end
    end

    def build_body_request
      # today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')
      today = Date.today.strftime('%Y%m%d')
      fecaereq = {"FeCAEReq" => { "FeCabReq" => { "CantReg" => "1", "CbteTipo" => bill.cbte_type, "PtoVta" => bill.sale_point },
                                  "FeDetReq" => { "FECAEDetRequest" => { "Concepto"   => Snoopy::CONCEPTS[bill.concept],
                                                                         "DocTipo"    => Snoopy::DOCUMENTS[bill.document_type],
                                                                         "CbteFch"    => today,
                                                                         "ImpTotConc" => 0.00,
                                                                         "MonId"      => Snoopy::CURRENCY[bill.currency][:code],
                                                                         "MonCotiz"   => bill.exchange_rate,
                                                                         "ImpOpEx"    => 0.00,
                                                                         "ImpTrib"    => 0.00 }}}}

      unless bill.issuer_iva_cond.to_sym == Snoopy::RESPONSABLE_MONOTRIBUTO
        _alicivas = bill.alicivas.collect do |aliciva|
          { 'Id' => Snoopy::ALIC_IVA[aliciva[:id].to_f], 'Importe' => aliciva[:amount], 'BaseImp' => aliciva[:taxeable_base] }
        end
        fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]["Iva"] = { "AlicIva" => _alicivas }
      end

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      detail["DocNro"]    = bill.document_num
      detail["ImpNeto"]   = bill.total_net.to_f
      detail["ImpIVA"]    = bill.iva_sum
      detail["ImpTotal"]  = bill.total
      detail["CbteDesde"] = detail["CbteHasta"] = bill.number

      unless bill.concept == "Productos"
        detail.merge!({ "FchServDesde" => bill.service_date_from || today,
                        "FchServHasta" => bill.service_date_to   || today,
                        "FchVtoPago"   => bill.due_date          || today})
      end

      if bill.receiver_iva_cond.to_s.include?("nota_credito")
        detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro"    => bill.cbte_asoc_num,
                                                      "PtoVta" => bill.cbte_asoc_to_sale_point,
                                                      "Tipo"   => bill.cbte_type }}})
      end

      @request = { "Auth" => auth }.merge!(fecaereq)
    rescue => e
      raise Snoopy::Exception::AuthorizeAdapter::BuildBodyRequest.new(e.message, e.backtrace)
    end

    def build_body_comp_cons_request
      fecompconsreq = { "FeCompConsReq" => { "CbteTipo" => bill.cbte_type, "CbteNro" => bill.number.to_i, "PtoVta" => bill.sale_point.to_i } }
      @comp_cons_request = { "Auth" => auth }.merge!(fecompconsreq)
    end

    def parse_observations(fecae_observations)
      fecae_observations.each_value do |obs|
        [obs].flatten.each { |ob| afip_observations[ob[:code]] = ob[:msg] }
      end
    rescue => e
      errors << Snoopy::Exception::AuthorizeAdapter::ObservationParser.new(e.message, e.backtrace)
    end

    def parse_events(fecae_events)
      fecae_events.each_value do |events|
        [events].flatten.each { |event| afip_events[event[:code]] = event[:msg] }
      end
    rescue => e
      errors << Snoopy::Exception::AuthorizeAdapter::EventsParser.new(e.message, e.backtrace)
    end

    def parse_errors(fecae_errors)
      fecae_errors.each_value do |errores|
        [errores].flatten.each { |error| afip_errors[error[:code]] = error[:msg] }
      end
    rescue => e
      errors << Snoopy::Exception::AuthorizeAdapter::ErrorParser.new(e.message, e.backtrace)
    end

    def parse_fecae_solicitar_response
      begin
        fecae_result   = response[:fecae_solicitar_response][:fecae_solicitar_result]
        fecae_response = fecae_result[:fe_det_resp][:fecae_det_response]

        bill.number       = fecae_response[:cbte_desde]
        bill.cae          = fecae_response[:cae]
        bill.due_date_cae = fecae_response[:cae_fch_vto]
        bill.result       = fecae_response[:resultado]
      rescue => e
        raise Snoopy::Exception::AuthorizeAdapter::FecaeSolicitarResultParser.new(e.message, e.backtrace)
      end

      begin
        bill.voucher_date = fecae_response[:cbte_fch]
        bill.process_date = fecae_result[:fe_cab_resp][:fch_proceso]

        parse_observations(fecae_response.delete(:observaciones)) if fecae_response.has_key? :observaciones
        parse_errors(fecae_result[:errors])                       if fecae_result.has_key? :errors
        parse_events(fecae_result[:events])                       if fecae_result.has_key? :events
      rescue => e
        @errors << Snoopy::Exception::AuthorizeAdapter::FecaeResponseParser.new(e.message, e.backtrace)
      end
    end

    def parse_fe_comp_consultar_response
      fe_comp_consultar_result = response[:fe_comp_consultar_response][:fe_comp_consultar_result]
      result_get               = fe_comp_consultar_result[:result_get]

      unless result_get.nil?
        bill.result            = result_get[:resultado]
        bill.number            = result_get[:cbte_desde]
        bill.cae               = result_get[:cod_autorizacion]
        bill.due_date_cae      = result_get[:fch_vto]
        bill.imp_iva           = result_get[:imp_iva]
        bill.document_num      = result_get[:doc_numero]
        bill.process_date      = result_get[:fch_proceso]
        bill.voucher_date      = result_get[:cbte_fch]
        bill.service_date_to   = result_get[:fch_serv_hasta]
        bill.service_date_from = result_get[:fch_serv_desde]
        parse_events(result_get[:observaciones]) if result_get.has_key? :observaciones
      end

      self.parse_errors(fe_comp_consultar_result[:errors]) if fe_comp_consultar_result and fe_comp_consultar_result.has_key? :errors
      self.parse_events(fe_comp_consultar_result[:events]) if fe_comp_consultar_result and fe_comp_consultar_result.has_key? :events
    rescue => e
      @errors << Snoopy::Exception::FecompConsultResponseParser.new(e.message, e.backtrace)
    end

    def client_configuration
      { :wsdl              => Snoopy.service_url,
        :headers           => { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" },
        :namespaces        => {"xmlns" => "http://ar.gov.afip.dif.FEV1/"},
        :ssl_version       => :TLSv1,
        :read_timeout      => Snoopy.read_timeout,
        :open_timeout      => Snoopy.open_timeout,
        :ssl_cert_file     => cert,
        :ssl_cert_key_file => pkey,
        :pretty_print_xml  => true }
    end
  end
end
