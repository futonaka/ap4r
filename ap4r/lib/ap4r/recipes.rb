config = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

config.load do
  namespace :ap4r do
    desc <<-DESC
      Deploys your project. This calls both 'deploy:update' and 'ap4r:restart'.
      Note that this will generally only work for applications that have
      already been deployed once. For a "cold" deploy, you will want to take
      a look at the 'ap4r:cold' task, which handles the cold start
      specifically.
    DESC
    task :default do
      update
      restart
    end

    desc <<-DESC
      Setups your project space. This make some shared directories (by 'deploy.update')
      and additionallly make uuid.state in the shared/ direcotory.
    DESC
    task :setup do
      deploy.setup
      run <<-CMD
        ruby -e 'require "rubygems"; require "uuid"; Dir.chdir("#{shared_path}"){UUID.new}' > /dev/null
      CMD
    end
    
    desc <<-DESC
      Deploys and starts a "cold" application. This is useful if you have not
      deployed your application before, or if your application is (for some
      other reason) not currently running. It will deploy the code, and
      invoke 'ap4r:start' to fire up the AP4R servers.
    DESC
    task :cold do
      update
      start
    end

    desc <<-DESC
      Start AP4R process on the ap4r server.  This uses the :use_sudo variable
      to determine whether to use sudo or not. By default, :use_sudo is
      set to true.
    DESC
    task :start, :roles => :ap4r do
      run_mongrel_ap4r("start", "-d -A #{ap4r_conf}")
    end

    desc <<-DESC
      Restart the AP4R process on the ap4r server by starting and stopping the
      AP4R. This uses the :use_sudo variable to determine whether to use sudo
      or not. By default, :use_sudo is set to true.
    DESC
    task :restart, :roles => :ap4r do
      stop
      start
    end

    desc <<-DESC
      Stop the AP4R process on the ap4r server.  This uses the :use_sudo
      variable to determine whether to use sudo or not. By default, :use_sudo is
      set to true.
    DESC
    task :stop, :roles => :ap4r do
      run_mongrel_ap4r("stop")
    end

    desc <<-DESC
      Rolls back to a previous version and restarts.
    DESC
    task :rollback do
      deploy.rollback_code
      restart
    end

    desc <<-DESC
      Updates your code from repository and makes symlinks for shared resourses.
    DESC
    task :update do
      transaction do
        deploy.update_code
        deploy.symlink

        finalize_update
      end
    end

    # Makes some symlinks.
    # One for the queues dir of disk message store.
    # And one for the uuid.state file.
    task :finalize_update do
      require 'ap4r'
      set_ap4r_conf

      # TODO: This logic needs the config file at local to be synchronized to svn 2007/10/12 by shino
      config = ReliableMsg::Config.new(ap4r_conf)
      config.load_no_create
      if config.store["type"] == "disk"
        queue_path = config.store["path"] || ReliableMsg::Config::DEFAULT_STORE["path"]
        latest_queue_path = "#{latest_release}/#{queue_path}"
        shared_queue_path = "#{shared_path}/#{queue_path}"
        # mkdir -p is making sure that the directories are there for some SCM's that don't
        # save empty folders
        run "umask 02 && mkdir -p #{shared_queue_path}/"
        run <<-CMD
          rm -rf #{latest_queue_path} &&
          ln -s #{shared_queue_path} #{latest_queue_path} &&
          ln -s #{shared_path}/uuid.state #{latest_release}/uuid.state
        CMD
      end
    end

    def run_mongrel_ap4r(command, options="")
      set_ap4r_conf
      send(run_method, "ruby #{current_path}/script/mongrel_ap4r #{command} -c  #{current_path} #{options}")
    end
    
    def set_ap4r_conf
      set :ap4r_conf, "#{application}/config/queues.cfg" unless ap4r_conf
    end
  end

end
