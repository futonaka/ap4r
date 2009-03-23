# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

$KCODE = 'u'

require 'singleton'
require 'rubygems'
require 'ap4r'
require 'ap4r/util/queue_client'

class Ap4r::Configuration #:nodoc:
  SETTINGS_FILES_DEFAULT = %w( config/ap4r_settings.rb )

  class Services #:nodoc:
    include Singleton
    include Enumerable

    def initialize
      @list = []
    end

    def add(*args)
      client = Ap4r::Util::QueueClient.new(*args)
      @list << (client)
    end

    def each(&block)
      @list.each(&block)
    end
  end

  class << self
    def setup
      yield Services.instance
    end

    def services
      Services.instance
    end

    def load_setting_files(settings_files = SETTINGS_FILES_DEFAULT)
      settings_files.each{ |file|
        load(file) if FileTest.file?(file)
      }
    end
  end

end

# This class is TOO MUCH EXPERIMENTAL.
#
# IRM is the interactive reliable-msg shell.
class IRM
  class << self
    def [](name)
      sym_name = name.to_sym
      Ap4r::Configuration.services.find{|service| service.name == sym_name }
    end
  end
end

#--

def each(&block)
  Ap4r::Configuration.services.each(&block)
end
extend Enumerable

Ap4r::Configuration.load_setting_files

$original_main = self

class Object #:nodoc:
  Ap4r::Configuration.services.each {|s|
    module_eval <<-EOS
      def #{s.name.to_s}
        irb_change_workspace(IRM[:#{s.name.to_s}])
      end
    EOS
  }

  def main
    irb_change_workspace($original_main)
    nil
  end

end

require 'irb'
IRB.start

#++
