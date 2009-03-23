# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

# Sample script to use Log4R

require 'rubygems'
require 'log4r'
require 'log4r/yamlconfigurator'
# we use various outputters, so require them, otherwise config chokes
require 'log4r/outputter/datefileoutputter'
require 'log4r/outputter/emailoutputter'

include Log4r

cfg = YamlConfigurator
cfg['HOME'] = '.'

cfg.load_yaml_file('log4r.yaml')

log4r_logger = Log4r::Logger.get 'mylogger'
#log4r_logger.outputters = Log4r::Outputter.stdout


require 'ap4r'
manager = ReliableMsg::QueueManager.new( {:config => 'queues.cfg',
                                           :logger => log4r_logger })
manager.start

begin
  while manager.alive?
    sleep 3
  end
rescue Interrupt
  manager.stop
end

