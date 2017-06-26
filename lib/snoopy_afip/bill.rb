# coding: utf-8
module Snoopy
  class Bill
    attr_accessor :total_net, :document_num, :document_type, :concept, :currency, :result,
                  :cbte_asoc_num, :cae, :service_date_to, :due_date,
                  :number, :alicivas, :cuit, :sale_point, :service_date_from,
                  :due_date_cae, :voucher_date, :process_date, :imp_iva, :cbte_asoc_sale_point,
                  :receiver_iva_cond, :issuer_iva_cond, :errors

    ATTRIBUTES = [ :total_net, :document_num, :document_type, :concept, :currency, :result,
                   :cbte_asoc_num, :cae, :service_date_to, :due_date,
                   :number, :alicivas, :cuit, :sale_point, :service_date_from,
                   :due_date_cae, :voucher_date, :process_date, :imp_iva, :cbte_asoc_sale_point,
                   :receiver_iva_cond, :issuer_iva_cond, :errors ]

    TAX_ATTRIBUTES = [ :id, :amount, :taxeable_base ]

    ATTRIBUTES_PRECENSE = [:total_net, :concept, :receiver_iva_cond, :alicivas, :document_type, :service_date_from, :service_date_to, :sale_point, :issuer_iva_cond]

    def initialize(attrs={})
      # attrs = attrs.deep_symbolize_keys
      @cuit                    = attrs[:cuit]
      @result                  = nil
      @number                  = nil
      @errors                  = {}
      @concept                 = attrs[:concept] || Snoopy.default_concept
      @imp_iva                 = attrs[:imp_iva] # Monto total de impuestos
      @currency                = attrs[:currency] || Snoopy.default_currency
      @alicivas                = attrs[:alicivas]
      @total_net               = attrs[:total_net] || 0
      @sale_point              = attrs[:sale_point]
      @document_num            = attrs[:document_num]
      @cbte_asoc_num           = attrs[:cbte_asoc_num] # Esto es el numero de factura para la nota de credito
      @document_type           = attrs[:document_type] || Snoopy.default_document_type
      @issuer_iva_cond         = attrs[:issuer_iva_cond]
      @service_date_to         = attrs[:service_date_to]
      @service_date_from       = attrs[:service_date_from]
      @receiver_iva_cond       = attrs[:receiver_iva_cond]
      @cbte_asoc_to_sale_point = attrs[:cbte_asoc_to_sale_point] # Esto es el punto de venta de la factura para la nota de credito
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

    # Para probar que la conexion con afip es correcta, si este metodo devuelve true, es posible realizar cualquier consulta al ws de la AFIP.
    # def connection_valid?
    #   # result = client.call(:fe_dummy).body[:fe_dummy_response][:fe_dummy_result]
    #   result = client_call(:fe_dummy)[:fe_dummy_response][:fe_dummy_result]
    #   @afip_observations[:db_server]   = result[:db_server]
    #   @afip_observations[:app_server]  = result[:app_server]
    #   @afip_observations[:auth_server] = result[:auth_server]
    #   result[:app_server] == 'OK' and result[:db_server] == 'OK' and result[:auth_server] == 'OK'
    # end

    def exchange_rate
      return 1 if currency == :peso
      # response = client.fe_param_get_cotizacion do |soap|
      #   soap.namespaces["xmlns"] = "http://ar.gov.afip.dif.FEV1/"
      #   soap.body = body.merge!({"MonId" => Snoopy::CURRENCY[currency][:code]})
      # end
      # response.to_hash[:fe_param_get_cotizacion_response][:fe_param_get_cotizacion_result][:result_get][:mon_cotiz].to_f
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

    def approved?
      result == 'A'
    end

    def rejected?
      result == 'R'
    end

    def partial_approved?
      result == 'P'
    end

    def valid?
      validate!
    end

    private

    def validate!
      # validate_attributes_name(attrs)
      @errors = {}
      validate_attributes_presence
      validate_standar_values
    end

    def validate_attributes_presence
      missing_attributes = []
      ATTRIBUTES_PRECENSE.each { |_attr| missing_attributes << _attr if (self.send(_attr).blank? || self.send(_attr).nil?) }

      @alicivas.each { |imp| missing_attributes += Snoopy::Bill::TAX_ATTRIBUTES - imp.keys }

      missing_attributes.uniq.each do |attr|
        @errors[attr.to_sym] = [] unless errors.has_key?(attr)
        @errors[attr.to_sym] << Snoopy::Exception::Bill::MissingAttributes.new(attr).message
      end

    end

    def validate_standar_values
      status = true
      unless Snoopy::CURRENCY.keys.include?(@currency.to_sym)
        @errors[:currency] = [] unless errors.has_key?(:currency)
        @errors[:currency] << Snoopy::Exception::Bill::InvalidValueAttribute.new("Invalid value #{@currency}, Possible values #{Snoopy::CURRENCY.keys}").message
        status = false unless errors.empty?
      end

      unless Snoopy::IVA_COND.include?(@issuer_iva_cond.to_sym)
        @errors[:issuer_iva_cond] = [] unless errors.has_key?(:issuer_iva_cond)
        @errors[:issuer_iva_cond] << Snoopy::Exception::Bill::InvalidValueAttribute.new("Invalid value #{@issuer_iva_cond}. Possible values #{Snoopy::IVA_COND}").message
        status = false unless errors.empty?
      end

      unless Snoopy::BILL_TYPE.keys.include?(@receiver_iva_cond.to_sym)
        @errors[:receiver_iva_cond] = [] unless errors.has_key?(:receiver_iva_cond)
        @errors[:receiver_iva_cond] << Snoopy::Exception::Bill::InvalidValueAttribute.new("Invalid value #{@receiver_iva_cond}. Possible values #{Snoopy::BILL_TYPE.keys}").message
        status = false unless errors.empty?
      end

      unless Snoopy::DOCUMENTS.keys.include?(@document_type)
        @errors[:document_type] = [] unless errors.has_key?(:document_type)
        @errors[:document_type] << Snoopy::Exception::Bill::InvalidValueAttribute.new("Invalid value #{@document_type}. Possible values #{Snoopy::DOCUMENTS.keys}").message
        status = false unless errors.empty?
      end

      unless Snoopy::CONCEPTS.keys.include?(@concept)
        @errors[:concept] = [] unless errors.has_key?(:concept)
        @errors[:concept] << Snoopy::Exception::Bill::InvalidValueAttribute.new("Invalid value #{@concept}. Possible values #{Snoopy::CONCEPTS.keys}").message
        status = false unless errors.empty?
      end
      status
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
  end
end
