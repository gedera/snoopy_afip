require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

RSpec.describe Snoopy::Bill do
  def valid_attrs(overrides = {})
    {
      cuit:                   "20111111112",
      sale_point:             "0001",
      total_net:              100.0,
      concept:                "Productos",
      document_type:          "CUIT",
      document_num:           "30710151543",
      issuer_iva_cond:        Snoopy::RESPONSABLE_INSCRIPTO,
      receiver_iva_cond:      :factura_a,
      receiver_iva_condition: :responsable_inscripto,
      currency:               :peso,
      service_date_from:      "20240101",
      service_date_to:        "20240131",
      alicivas:               [{ id: 0.21, amount: 21.0, taxeable_base: 100.0 }]
    }.merge(overrides)
  end

  describe "#cbte_type" do
    it "deriva el código del comprobante desde receiver_iva_cond" do
      expect(described_class.new(valid_attrs).cbte_type).to eq("01")          # BILL_TYPE[:factura_a]
      expect(described_class.new(valid_attrs(receiver_iva_cond: :factura_b)).cbte_type).to eq("06")
    end
  end

  describe "#iva_sum y #total" do
    it "suma las alícuotas y calcula el total neto + IVA" do
      bill = described_class.new(valid_attrs)
      expect(bill.iva_sum).to eq(21.0)
      expect(bill.total).to eq(121.0)
    end

    it "total es 0 cuando el neto es 0" do
      expect(described_class.new(valid_attrs(total_net: 0)).total).to eq(0)
    end
  end

  describe "#exchange_rate" do
    it "es 1 para pesos" do
      expect(described_class.new(valid_attrs(currency: :peso)).exchange_rate).to eq(1)
    end
  end

  describe "#receiver_iva_condition_id" do
    it "mapea la condición de IVA del receptor (RG 5616)" do
      expect(described_class.new(valid_attrs).receiver_iva_condition_id).to eq("1")
      expect(described_class.new(valid_attrs(receiver_iva_condition: :consumidor_final)).receiver_iva_condition_id).to eq("5")
    end

    it "es '' cuando no se informó la condición" do
      expect(described_class.new(valid_attrs(receiver_iva_condition: nil)).receiver_iva_condition_id).to eq("")
    end
  end

  describe "estado del resultado" do
    it "refleja el veredicto de AFIP" do
      bill = described_class.new(valid_attrs)
      bill.result = "A"
      expect(bill.approved?).to be(true)
      bill.result = "R"
      expect(bill.rejected?).to be(true)
      bill.result = "P"
      expect(bill.partial_approved?).to be(true)
    end
  end

  describe "#valid?" do
    it "es válido con atributos completos y correctos" do
      bill = described_class.new(valid_attrs)
      expect(bill.valid?).to be(true)
      expect(bill.errors).to be_empty
    end

    it "marca currency inválida" do
      bill = described_class.new(valid_attrs(currency: :yen))
      expect(bill.valid?).to be(false)
      expect(bill.errors).to have_key(:currency)
    end

    it "marca document_type inválido" do
      bill = described_class.new(valid_attrs(document_type: "NOPE"))
      bill.valid?
      expect(bill.errors).to have_key(:document_type)
    end
  end
end
