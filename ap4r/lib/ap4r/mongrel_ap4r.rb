# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Corp.
# Licence:: MIT Licence

require 'rubygems'
require 'mongrel'
require 'ap4r/mongrel'

Mongrel::Command::BANNER.gsub!("rails", "ap4r")

module Ap4r::Mongrel

  module Command
    PREFIX = "ap4r::mongrel::"

    module Base
      def self.included(klass)
        return unless klass.kind_of?(Class)
        klass.class_eval do |k|
          include(::Mongrel::Command::Base)
        end


        # TODO: Can subclass the return of RubyGems::GemPlugin ? 2007/04/16 by shino
      end

      # send a signal to the process specified by pid_file.
      def send_signal(signal, pid_file)
        pid = open(pid_file).read.to_i
        print "Send signal #{signal} to AP4R at PID #{pid} ..."
        begin
          Process.kill(signal, pid)
        rescue Errno::ESRCH
          puts "Process not found."
        end
        puts "Done."
      end
    end

  end

  class Help < GemPlugin::Plugin "/commands"
    include ::Ap4r::Mongrel::Command::Base

    def run
      puts "Available AP4R commands are:\n\n"
      Mongrel::Command::Registry.instance.commands.each do |name|
        if name =~ /#{Command::PREFIX}/
          name = name[Command::PREFIX.length .. -1]
        end
        puts " - #{name[1 .. -1]}\n"
      end
      puts "\nfor further help, run each command with -h option to get help."
    end

  end

  class Version < GemPlugin::Plugin "/commands"
    include ::Ap4r::Mongrel::Command::Base

    def run
      puts "AP4R Version is:"
      puts
      puts " - AP4R #{::Ap4r::VERSION::STRING}"
      puts
    end

  end

  class Start < GemPlugin::Plugin "/commands"
    include ::Ap4r::Mongrel::Command::Base

    def configure
      options [
        ["-d", "--daemonize", "Run in daemon mode", :@daemon, false],
        ['-p', '--port PORT', "Port number used by mongrel", :@port, 7438],
        ['-a', '--address HOST', "IP address used by mongrel", :@host, "0.0.0.0"],
        ['-A', '--ap4r-config FILE', "Config file for reliable-msg/AP4R", :@ap4r_config_file, "config/queues.cfg"],
        ['-l', '--log FILE', "Log file", :@log_file, "log/mongrel_ap4r.log"],
        ['-P', '--pid FILE', "PID file", :@pid_file, "log/mongrel_ap4r.pid"],
        ['-r', '--root PATH', "Document root (no meanings yet.)", :@docroot, "public"],
        ['-c', '--chdir PATH', "Change to dir", :@cwd, Dir.pwd],
      ]
    end

    def validate
      @cwd = File.expand_path(@cwd)
      valid_dir? @cwd, "Path of chdir not valid: #@cwd "
      Dir.chdir(@cwd)

      valid_dir? File.dirname(@log_file), "Path to log file not valid: #@log_file"
      valid_dir? File.dirname(@pid_file), "Path to pid file not valid: #@pid_file"
      valid_dir? @docroot, "Path to docroot not valid: #@docroot"

      return @valid
    end

    def run
      settings = {
        :host => @host,  :port => @port,
        :log_file => @log_file, :pid_file => @pid_file,
        :docroot => @docroot,
        :daemon => @daemon,
        :ap4r_config_file => @ap4r_config_file,
      }

      config = ::Ap4r::Mongrel::Ap4rConfigurator.new(settings) do
        if defaults[:daemon]
          if File.exist? defaults[:pid_file]
            log "PID file #{defaults[:pid_file]} exists!!! Exiting with error."
            exit 1
          end
          daemonize({:log_file => @log_file, :cwd => File.expand_path(".") })
        end

        listener do
          log "Starting AP4R Handler with #{defaults[:ap4r_config_file]}"
          uri "/", :handler => ::Ap4r::Mongrel::Ap4rHandler.new(defaults)
          uri "/queues", :handler => ::Ap4r::Mongrel::Ap4rSendMessageHandler.new(defaults)
          uri "/subscribes", :handler => ::Ap4r::Mongrel::Ap4rSubscribeMessageHandler.new(defaults)
          uri "/monitoring", :handler => ::Ap4r::Mongrel::Ap4rMonitoringHandler.new(defaults)
        end
        setup_signals(settings)
      end

      config.run
      config.log "Mongrel available at #{settings[:host]}:#{settings[:port]}"

      if config.defaults[:daemon]
        config.write_pid_file
      else
        config.log "Use CTRL-C to stop."
      end

      config.log "Mongrel start up process completed."
      config.join

      if config.needs_restart
        if RUBY_PLATFORM !~ /mswin/
          cmd = "ruby #{__FILE__} start #{original_args.join(' ')}"
          config.log "Restarting with arguments:  #{cmd}"
          config.stop
          config.remove_pid_file

          if config.defaults[:daemon]
            system cmd
          else
            STDERR.puts "Can't restart unless in daemon mode."
            exit 1
          end
        else
          config.log "Win32 does not support restarts. Exiting."
        end
      end
    end

  end

  class Stop < GemPlugin::Plugin "/commands"
    include ::Ap4r::Mongrel::Command::Base

    def configure
      options [
        ['-c', '--chdir PATH', "Change to dir", :@cwd, Dir.pwd],
        ['-P', '--pid FILE', "PID file", :@pid_file, "log/mongrel_ap4r.pid"],
        ['-f', '--force', "Force the shutdown (kill -9).", :@force, false],
        ['-w', '--wait SECONDS', "Wait SECONDS before forcing shutdown", :@wait, "0"],
      ]
    end

    def validate
      @cwd = File.expand_path(@cwd)
      valid_dir? @cwd, "Path of chdir not valid: #@cwd "
      Dir.chdir(@cwd)

      valid_dir? File.dirname(@pid_file), "Path to pid file not valid: #@pid_file"

      return @valid
    end

    def run
      if @force
        @wait.to_i.times do |waiting|
          exit(0) if not File.exist? @pid_file
          sleep 1
        end
        send_signal("KILL", @pid_file) if File.exist? @pid_file
      else
        send_signal("TERM", @pid_file)
      end
    end
  end

  class Restart < GemPlugin::Plugin "/commands"
    include ::Ap4r::Mongrel::Command::Base

    def configure
      options [
        ['-c', '--chdir PATH', "Change to dir", :@cwd, Dir.pwd],
        ['-P', '--pid FILE', "PID file", :@pid_file, "log/mongrel_ap4r.pid"],
      ]
    end

    def validate
      @cwd = File.expand_path(@cwd)
      valid_dir? @cwd, "Path of chdir not valid: #@cwd "
      Dir.chdir(@cwd)

      valid_dir? File.dirname(@pid_file), "Path to pid file not valid: #@pid_file"

      return @valid
    end

    def run
      send_signal("USR2", @pid_file)
    end
  end

  # TODO: add Reload(reliable-msg) command class 2007/04/16 by shino

end


def main(args)
  cmd_name = args.shift

  begin
    # TODO not all commands are implemented 2007/04/16 by shinohara
    if %w(help version start stop restart reload).include? cmd_name
      cmd_name = ::Ap4r::Mongrel::Command::PREFIX + cmd_name
    end

    command = GemPlugin::Manager.instance.create("/commands/#{cmd_name}", :argv => args)
  rescue OptionParser::InvalidOption
    STDERR.puts "#$! for command '#{cmd_name}'"
    STDERR.puts "Try #{cmd_name} -h to get help."
    return false
  rescue
    STDERR.puts "ERROR RUNNING '#{cmd_name}': #$!"
    STDERR.puts "Use help command to get help"
    return false
  end

  if not command.done_validating
    if not command.validate
      STDERR.puts "#{cmd_name} reported an error. Use mongrel_rails #{cmd_name} -h to get help."
      return false
    else
      command.run
    end
  end

  return true
end

# TODO: This script is not yet proper form of GemPlugin 2007/04/16 by shinohara
#GemPlugin::Manager.instance.load "ap4r" => GemPlugin::INCLUDE, "rails" => GemPlugin::EXCLUDE

unless main(ARGV)
  exit(1)
end
