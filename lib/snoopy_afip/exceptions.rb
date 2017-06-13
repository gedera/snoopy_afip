module Snoopy
  module Exception
    class  Exception < ::StandardError
      attr_accessor :backtrace

      def initialize(msg, backtrace)
        @backtrace = backtrace
        super(msg)
      end
    end

    class NullOrInvalidAttribute < StandardError
    end

    class NonExistAttributes < Exception
      def initialize(attributes, backtrace=nil)
        @backtrace = backtrace
        super("Non exist attributes: #{attributes}", backtrace)
      end
    end

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

    class ObservationParser < Exception
    end

    class ErrorParser < Exception
    end

    class EventsParser < Exception
    end

    class FecaeResponseParser < Exception
    end

    class FecompConsultResponseParser < Exception
    end

    class SetBillNumberParser < Exception
    end

    class BuildBodyRequest < Exception
    end

    class FecaeSolicitarResultParser < Exception
    end
  end

  class AfipTimeout < Timeout::Error
  end
end
