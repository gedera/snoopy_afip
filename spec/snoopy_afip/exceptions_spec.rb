require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

RSpec.describe Snoopy::Exception do
  # Regresión #14: ServerTimeout debe seguir siendo un Timeout::Error (compat
  # hacia atrás) y a la vez quedar bajo el paraguas Snoopy::Exception::Error.
  describe "jerarquía de ServerTimeout" do
    subject(:ancestors) { Snoopy::Exception::ServerTimeout.ancestors }

    it "sigue siendo un Timeout::Error" do
      expect(ancestors).to include(Timeout::Error)
    end

    it "queda bajo el paraguas Snoopy::Exception::Error" do
      expect(ancestors).to include(Snoopy::Exception::Error)
    end
  end

  it "el paraguas Error cubre también a las excepciones de la base" do
    expect(Snoopy::Exception::ClientError.ancestors).to include(Snoopy::Exception::Error)
    expect(Snoopy::Exception::AuthorizeAdapter::BuildBodyRequest.ancestors).to include(Snoopy::Exception::Error)
  end

  it "un rescue del paraguas atrapa tanto el timeout como los errores de cliente" do
    expect { raise Snoopy::Exception::ServerTimeout }.to raise_error(Snoopy::Exception::Error)
    expect { raise Snoopy::Exception::ClientError.new("x") }.to raise_error(Snoopy::Exception::Error)
  end
end
