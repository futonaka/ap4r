# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'fileutils'
require 'optparse'

module Ap4r
  module Script
    class WorkspaceGenerator < Base
      AP4R_Directories = %w(config log public script tmp)

      def run argv, options
        OptionParser.new {|opt|
          opt.on('-m'){
            # merge to rails project but not implemented yet...
          }

          opt.parse!(argv)
        }

        dir = argv.last
        unless dir
          logger.warn{"Specify a name of application root directory."}
          exit(1)
        end

        root_dir = File.expand_path(dir)

        logger.info{"make application root directory [#{root_dir}] ... "}
        FileUtils.mkdir_p(root_dir)

        logger.info{"make directories for AP4R [#{AP4R_Directories.join(", ")}] ..."}
        FileUtils.mkdir_p(AP4R_Directories.map{|d| File.join(root_dir, d)})

        %w(config script).each{ |recursive_copy_dir|
          copy_files(File.join(ap4r_base, recursive_copy_dir),
                     File.join(root_dir, recursive_copy_dir))
        }

        copy_file(File.join(ap4r_base, "fresh_rakefile"), File.join(root_dir, "Rakefile"))

        logger.info{"\n[#{root_dir}] has successfully set up!\n"}

      end

      private
      def copy_files(src_dir, dest_dir, excludes = /^\.|~$/, recursive = true)
        logger.info{"copy files from #{File.expand_path(src_dir)} to #{dest_dir} ..."}
        Dir.foreach(src_dir) {|name|
          next if name =~ excludes
          path = File.join(src_dir, name)
          FileUtils.cp(path, dest_dir) if FileTest.file?(path)

          if recursive && FileTest.directory?(path)
            next_dest_dir = File.join(dest_dir, name)
            FileUtils.mkdir_p(next_dest_dir)
            copy_files(path, next_dest_dir, excludes, recursive)
          end
        }
      end

      def copy_file(src, dest)
        FileUtils.cp(src, dest)
        logger.info{"copy file from #{File.expand_path(src)} to #{dest} ..."}
      end

    end
  end
end


