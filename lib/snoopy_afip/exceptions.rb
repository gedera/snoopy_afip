require "timeout" # ServerTimeout < Timeout::Error; en Ruby 3.4+ timeout es default gem no autocargado

module Snoopy
  module Exception

    # Paraguas de todos los errores que emite la gema. Se incluye en la base
    # `Exception` (y por herencia en todas sus subclases) y en `ServerTimeout`,
    # que debe seguir siendo un `Timeout::Error` por compatibilidad hacia atrás.
    # Permite `rescue Snoopy::Exception::Error` para atrapar cualquier error de
    # la gema, incluido el timeout, sin romper `rescue Timeout::Error`.
    module Error; end

    class  Exception < ::StandardError
      include Error

      attr_accessor :backtrace

      def initialize(msg, backtrace)
        @backtrace = backtrace
        super(msg)
      end
    end

    class ClientError < Exception
      def initialize(msj)
        super(msj, nil)
      end
    end

    class ServerTimeout < Timeout::Error
      include Error
    end

    module AuthenticationAdapter
      class CmsBuilder < Exception
      end
    end

    module AuthorizeAdapter
      class SetBillNumberParser < Exception
      end

      class BuildBodyRequest < Exception
      end

      class ObservationParser < Exception
      end

      class ErrorParser < Exception
      end

      class EventsParser < Exception
      end

      class FecaeSolicitarResultParser < Exception
      end

      class FecaeResponseParser < Exception
      end

      class FecompConsultResponseParser < Exception
      end
    end

    module Bill
      # class NonExistAttributes < Exception
      #   def initialize(attributes, backtrace=nil)
      #     @backtrace = backtrace
      #     super("Non exist attributes: #{attributes}", backtrace)
      #   end
      # end

      class MissingAttributes < Exception
        def initialize(attributes, backtrace=nil)
          @backtrace = backtrace
          super("Missing attributes: #{attributes}", backtrace)
        end
      end

      class InvalidValueAttribute < Exception
        def initialize(attribute, backtrace=nil)
          @backtrace = backtrace
          super("Invalid value for: #{attribute}", backtrace)
        end
      end
    end
  end
end
