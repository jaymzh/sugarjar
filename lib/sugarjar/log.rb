require 'mixlib/log'

module Mixlib
  module Log
    # A simple formatter so that 'info' is just like 'puts'
    # but everything else gets a severity
    class Formatter
      def call(severity, _time, _progname, msg)
        if severity == 'INFO'
          "#{msg2str(msg)}\n"
        else
          "#{severity}: #{msg2str(msg)}\n"
        end
      end
    end
  end
end

class SugarJar
  # Our singleton logger
  class Log
    extend Mixlib::Log
  end
end
