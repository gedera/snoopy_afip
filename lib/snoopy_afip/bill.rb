# coding: utf-8
module Snoopy
  class Bill
    attr_accessor :total_net, :document_num, :document_type, :concept, :currency, :result, :issuer_iva_cond,
                  :due_date, :aliciva_id, :body, :response, :cbte_asoc_num, :cae, :service_date_to,
                  :number, :alicivas, :pkey, :cert, :cuit, :sale_point, :auth, :service_date_from,
                  :due_date_cae, :voucher_date, :process_date, :imp_iva, :cbte_asoc_sale_point,
                  :receiver_iva_cond, :issuer_iva_cond, :afip_observations, :afip_events, :afip_errors, :errors

    ATTRIBUTES = [ :total_net, :document_num, :document_type, :concept, :currency, :result, :issuer_iva_cond,
                   :due_date, :aliciva_id, :body, :response, :cbte_asoc_num, :cae, :service_date_to,
                   :number, :alicivas, :pkey, :cert, :cuit, :sale_point, :auth, :service_date_from,
                   :due_date_cae, :voucher_date, :process_date, :imp_iva, :cbte_asoc_sale_point,
                   :receiver_iva_cond, :issuer_iva_cond, :afip_observations, :afip_events, :afip_errors, :errors ]

    TAX_ATTRIBUTES = [ :id, :amount, :taxeable_base ]

    ATTRIBUTES_PRECENSE = [:total_net, :concept, :receiver_iva_cond, :alicivas, :document_type, :document_num, :service_date_from, :service_date_to, :pkey, :cert, :cuit, :sale_point, :issuer_iva_cond]

    def initialize(attrs={})
      # attrs = attrs.deep_symbolize_keys
      @cuit                    = attrs[:cuit]
      @auth                    = attrs[:auth]
      @pkey                    = attrs[:pkey]
      @cert                    = attrs[:cert]
      @errors                  = {}
      @events                  = {}
      @concept                 = attrs[:concept] || Snoopy.default_concept
      @imp_iva                 = attrs[:imp_iva] # Monto total de impuestos
      @currency                = attrs[:currency] || Snoopy.default_currency
      @alicivas                = attrs[:alicivas]
      @response                = nil
      @total_net               = attrs[:total_net] || 0
      @sale_point              = attrs[:sale_point]
      @observations            = {}
      @document_num            = attrs[:document_num]
      @cbte_asoc_num           = attrs[:cbte_asoc_num] # Esto es el numero de factura para la nota de credito
      @document_type           = attrs[:document_type] || Snoopy.default_document_type
      @issuer_iva_cond         = attrs[:issuer_iva_cond]
      @service_date_to         = attrs[:service_date_to]
      @service_date_from       = attrs[:service_date_from]
      @receiver_iva_cond       = attrs[:receiver_iva_cond]
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
      @iva_sum = alicivas.collect{|aliciva| aliciva[:amount].to_f }.sum.to_f.round_with_precision(2)
    end

    def cbte_type
      Snoopy::BILL_TYPE[receiver_iva_cond.to_sym]
    end

    # def cbte_type
    #   Snoopy::BILL_TYPE[receiver_iva_cond.to_sym] || raise(Snoopy::Exception::NullOrInvalidAttribute.new('Please choose a valid document type.'))
    # end

    def client
      Savon.client( :wsdl              => Snoopy.service_url,
                    :headers           => { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" },
                    :namespaces        => {"xmlns" => "http://ar.gov.afip.dif.FEV1/"},
                    :ssl_version       => :TLSv1,
                    :read_timeout      => 90,
                    :open_timeout      => 90,
                    :ssl_cert_file     => cert,
                    :ssl_cert_key_file => pkey,
                    :pretty_print_xml  => true )
    end

    def client_call service, args={}
      begin
        Timeout::timeout(5) do
          client.call(service, args).body
        end
      rescue Timeout::Error
        raise(Snoopy::AfipTimeout.new)
      end
    end

    def set_bill_number!
      message = { "Auth" => auth, "PtoVta" => sale_point, "CbteTipo" => cbte_type }
      resp = client_call( :fe_comp_ultimo_autorizado, :message =>  message )

      begin
        resp_errors = resp[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
        resp_errors.each_value { |value| @errors[value[:code]] = value[:msg] } unless resp_errors.nil?
        @number = resp[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 if @errors.empty?
      rescue => e
        raise Snoopy::Exception::SetBillNumberParser.new(e.message, e.backtrace)
      end
    end

    def build_body_request
      # today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')
      today = Date.today.strftime('%Y%m%d')

        fecaereq = {"FeCAEReq" => { "FeCabReq" => { "CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => sale_point },
                                    "FeDetReq" => { "FECAEDetRequest" => { "Concepto"   => Snoopy::CONCEPTS[concept],
                                                                           "DocTipo"    => Snoopy::DOCUMENTS[document_type],
                                                                           "CbteFch"    => today,
                                                                           "ImpTotConc" => 0.00,
                                                                           "MonId"      => Snoopy::CURRENCY[currency][:code],
                                                                           "MonCotiz"   => exchange_rate,
                                                                           "ImpOpEx"    => 0.00,
                                                                           "ImpTrib"    => 0.00 }}}}

        unless issuer_iva_cond.to_sym == :responsable_monotributo
          _alicivas = alicivas.collect do |aliciva|
            { 'Id' => Snoopy::ALIC_IVA[aliciva[:id]], 'Importe' => aliciva[:amount], 'BaseImp' => aliciva[:taxeable_base] }
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
                          "FchServHasta" => service_date_to   || today,
                          "FchVtoPago"   => due_date          || today})
        end

        if self.receiver_iva_cond.to_s.include?("nota_credito")
          detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro"    => cbte_asoc_num,
                                                        "PtoVta" => cbte_asoc_to_sale_point,
                                                        "Tipo"   => cbte_type }}})
        end

        @body = { "Auth" => auth }.merge!(fecaereq)
      rescue => e
        raise Snoopy::Exception::BuildBodyRequest.new(e.message, e.backtrace)
    end

    def cae_request
      validate!
      set_bill_number!
      build_body_request
      # @response = Timeout::timeout(5) { client.call( :fecae_solicitar, :message => body ).body }
      @response = client_call( :fecae_solicitar, :message => body )
      parse_fecae_solicitar_response
      !@response.nil?
    end

    def approved?; @result == 'A'; end
    def rejected?; @result == 'R'; end
    def partial_approved?; @result == 'P'; end

    # Para probar que la conexion con afip es correcta, si este metodo devuelve true, es posible realizar cualquier consulta al ws de la AFIP.
    def connection_valid?
      # result = client.call(:fe_dummy).body[:fe_dummy_response][:fe_dummy_result]
      result = client_call(:fe_dummy)[:fe_dummy_response][:fe_dummy_result]
      @afip_observations[:db_server]   = result[:db_server]
      @afip_observations[:app_server]  = result[:app_server]
      @afip_observations[:auth_server] = result[:auth_server]
      result[:app_server] == 'OK' and result[:db_server] == 'OK' and result[:auth_server] == 'OK'
    end

    def parse_observations(fecae_observations)
      fecae_observations.each_value do |obs|
        [obs].flatten.each { |ob| @afip_observations[ob[:code]] = ob[:msg] }
      end
    rescue => e
      @errors << Snoopy::Exception::ObservationParser.new(e.message, e.backtrace)
    end

    def parse_events(fecae_events)
      fecae_events.each_value do |events|
        [events].flatten.each { |event| @afip_events[event[:code]] = event[:msg] }
      end
    rescue => e
      @errors << Snoopy::Exception::EventsParser.new(e.message, e.backtrace)
    end

    def parse_errors(fecae_errors)
      fecae_errors.each_value do |errores|
        [errores].flatten.each { |error| @afip_errors[error[:code]] = error[:msg] }
      end
    rescue => e
      @errors << Snoopy::Exception::ErrorParser.new(e.message, e.backtrace)
    end

    def parse_fecae_solicitar_response
      begin
        fecae_result   = @response[:fecae_solicitar_response][:fecae_solicitar_result]
        fecae_response = fecae_result[:fe_det_resp][:fecae_det_response]

        @number       = fecae_response[:cbte_desde]
        @cae          = fecae_response[:cae]
        @result       = fecae_response[:resultado]
        @due_date_cae = fecae_response[:cae_fch_vto]
      rescue => e
        raise(Snoopy::Exception::FecaeSolicitarResultParser.new(e.message, e.backtrace))
      end

      begin
        @voucher_date = fecae_response[:cbte_fch]
        @process_date = fecae_result[:fe_cab_resp][:fch_proceso]

        parse_observations(fecae_response.delete(:observaciones)) if fecae_response.has_key? :observaciones
        parse_errors(fecae_result[:errors])                       if fecae_result.has_key? :errors
        parse_events(fecae_result[:events])                       if fecae_result.has_key? :events
      rescue => e
        @errors << Snoopy::Exception::FecaeResponseParser.new(e.message, e.backtrace)
      end
    end

    def parse_fe_comp_consultar_response
      fe_comp_consultar_result = @response[:fe_comp_consultar_response][:fe_comp_consultar_result]
      result_get               = fe_comp_consultar_result[:result_get]

      unless result_get.nil?
        @number            = result_get[:cbte_desde]
        @cae               = result_get[:cod_autorizacion]
        @due_date_cae      = result_get[:fch_vto]
        @imp_iva           = result_get[:imp_iva]
        @result            = result_get[:resultado]
        @document_num      = result_get[:doc_numero]
        @process_date      = result_get[:fch_proceso]
        @voucher_date      = result_get[:cbte_fch]
        @service_date_to   = result_get[:fch_serv_hasta]
        @service_date_from = result_get[:fch_serv_desde]
        parse_events(result_get[:observaciones]) if result_get.has_key? :observaciones
      end

      self.parse_events(fe_comp_consultar_result[:errors]) if fe_comp_consultar_result and fe_comp_consultar_result.has_key? :errors
      self.parse_events(fe_comp_consultar_result[:events]) if fe_comp_consultar_result and fe_comp_consultar_result.has_key? :events
    rescue => e
      @errors << Snoopy::Exception::FecompConsultResponseParser.new(e.message, e.backtrace)
    end

    # def self.bill_request(number, attrs={})
    #   bill = Snoopy::Bill.new(attrs)
    #   bill.response = bill.client_call( :fe_comp_consultar,
    #                                     :message => {"Auth" => bill.auth,
    #                                                  "FeCompConsReq" => {"CbteTipo" => bill.cbte_type, "PtoVta" => bill.sale_point, "CbteNro" => number.to_s}})
    #   bill.parse_fe_comp_consultar_response
    #   bill
    # rescue => e
    #   binding.pry
    # end

    def valid?
      validate!
    end

    private

    def validate!
      # validate_attributes_name(attrs)
      validate_attributes_presence
      validate_standar_values
    end

    # def validate_attributes_name attrs
    #   attrs_not_found = attrs.keys - Snoopy::Bill::ATTRIBUTES
    #   imp_atts_not_found = []

    #   if attrs.has_key?(:alicivas)
    #     attrs[:alicivas].each { |imp| imp_atts_not_found += imp.keys - Snoopy::Bill::TAX_ATTRIBUTES }
    #   end

    #   _attrs = attrs_not_found + imp_atts_not_found.uniq
    #   raise Snoopy::Exception::NonExistAttributes.new(_attrs.join(', ')) if _attrs.present?
    # end

    def validate_attributes_presence
      ATTRIBUTES_PRECENSE.each { |_attr| missing_attributes << _attr if (self.send(_attr).blank? || self.send(_attr).nil?) }

      missing_tax_attributes = []
      @alicivas.each { |imp| missing_tax_attributes += Snoopy::Bill::TAX_ATTRIBUTES - imp.keys }

      _attrs = (missing_attributes + missing_tax_attributes.uniq)
      if _attrs.present?
        exception = Snoopy::Exception::MissingAttributes.new(_attrs.join(', '))
        @errors << exception
        raise exception
      end
    end

    def validate_standar_values
      unless Snoopy::CURRENCY.keys.include?(@currency.to_sym)
        exception = Snoopy::Exception::InvalidValueAttribute.new(":currency. Possible values #{Snoopy::CURRENCY.keys}")
        @errors << exception
        raise exception
      end

      unless Snoopy::IVA_COND.include?(@issuer_iva_cond.to_sym)
        exception = Snoopy::Exception::InvalidValueAttribute.new(":issuer_iva_cond. Possible values #{Snoopy::IVA_COND}")
        @errors << exception
        raise exception
      end

      unless Snoopy::BILL_TYPE.keys.include?(@receiver_iva_cond.to_sym)
        exception = Snoopy::Exception::InvalidValueAttribute.new(":receiver_iva_cond. Possible values #{Snoopy::BILL_TYPE.keys}")
        @errors << exception
        raise exception
      end

      unless Snoopy::DOCUMENTS.keys.include?(@document_type)
        exception = Snoopy::Exception::InvalidValueAttribute.new(":document_type. Possible values #{Snoopy::DOCUMENTS.keys}")
        @errors << exception
        raise exception
      end

      unless Snoopy::CONCEPTS.keys.include?(@concept)
        exception = Snoopy::Exception::InvalidValueAttribute.new(":concept. Possible values #{Snoopy::CONCEPTS.keys}")
        @errors << exception
        raise exception
      end
    end
  end
end
