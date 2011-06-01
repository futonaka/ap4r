require 'rubygems'
require 'erb'
require 'find'
require 'active_record'
require File.join(File.dirname(__FILE__), 'lib/ap4r', 'version')

begin
  namespace :hoe do
    require 'hoe'

    hoe = Hoe.new('ap4r-dispatcher', Ap4r::VERSION::STRING) do |p|
      p.author = ["Shunichi Shinohara", "Kiwamu Kato"]
      p.changes = p.paragraphs_of('History.txt', 1..2).join("\n\n")
      #p.clean_globs =
      p.description = <<-EOF
      Dispatcher of Asynchronous Processing for Ruby.
    EOF
      p.email = %q{shinohara.shunichi@future.co.jp, kato.kiwamu@future.co.jp}

      p.extra_deps << ['reliable-msg', '=1.1.0']
      p.extra_deps << ['activesupport']
      p.extra_deps << ['mongrel']
      p.extra_deps << ['rake']
      p.extra_deps << ['hoe']

      p.name = 'ap4r-dispatcher'
      p.need_tar = false
      p.need_zip = false
      p.rdoc_pattern = /^(lib|bin|ext|rails_plugin)|txt$/

      #p.remote_rdoc_dir =
      #p.rsync =
      p.rubyforge_name = 'ap4r-dispatcher'
      #p.spec_extra =
      p.summary = 'Dispatcher of Asynchronous Processing for Ruby.'
      p.test_globs = 'spec/**/*_spec.rb'
      p.url = 'http://ap4r.rubyforge.org/wiki/wiki.pl?HomePage'
      p.version = Ap4r::VERSION::STRING
    end
    hoe.spec.dependencies.delete_if {|dep| dep.name == "hoe"}

  end
rescue
end

# AP4R release tasks --------------------------------------------------------

#HelloWorld = '../samples/HelloWorld'
#HelloWorld = '../samples/hello_world_for_rails2'
ProjectName = 'hello_world_for_rails2'

namespace :release do
  desc "copy rails plugin from sample before gem build"
  task :copy_plugin do
    # TODO: Should use file task ? 2007/09/27 by shino
    FileUtils.rm_rf('./rails_plugin/ap4r')
    FileUtils.mkdir_p('./rails_plugin/ap4r/lib')
    FileUtils.cp(Dir.glob("../samples/#{ProjectName}/db/migrate/*.rb").first,
                 './lib/ap4r/xxx_create_table_for_saf.rb')
    FileUtils.cp_r(Dir.glob("../samples/#{ProjectName}/vendor/plugins/ap4r/*").reject{|f| f =~ /tmp$|CVS|\.svn/},
                   './rails_plugin/ap4r')
    # TODO: dot files and tilde files are copied 2007/09/20 by shino
  end

  desc "Create Manifest.txt"
  task :create_manifest => [:copy_plugin] do
    path_list = []
    Find.find('.') do |path|
      next unless File.file?(path)
      next if path =~ /^\.\/coverage\//
      next if path =~ /^\.\/doc\//
      next if path =~ /^\.\/log\//
      next if path =~ /\.svn|tmp$|CVS|\.msg$|\.idx$|\.state$|\#$|\~$/
      path_list << path
    end

    File.open('Manifest.txt', 'w') do |manifest|
      path_list.sort.each do |path|
        /.\// =~ path
        manifest.puts($~.post_match)
      end
    end
  end

  # Sample release tasks ------------------------------------------------------
  desc 'Make sample tarball (Now only one sample "HelloWorld").'
  task :sample do
    FileUtils.mkdir_p('./pkg/samples')
    FileUtils.rm_rf("./pkg/samples/#{ProjectName}")

    FileUtils.cp_r("../samples/#{ProjectName}", './pkg/samples/')
    Find.find('./pkg/samples') do |path|
      next unless File.file? path
      FileUtils.rm_rf(path) if path =~ /\.svn|tmp$|CVS|.rb\~/
    end

    Dir.chdir("./pkg/samples/#{ProjectName}")
    `rake db:migrate`
    Dir.chdir('../../')

    `tar czf HelloWorld-#{Ap4r::VERSION::STRING}.tar.gz ./samples/#{ProjectName}/`
    Dir.chdir('../')
  end
end

task :pkg => "release:copy_plugin"

# Spec tasks ----------------------------------------------------------------
require 'spec/rake/spectask'

namespace :spec do
  %w(local).each do |flavor|
    desc "Run #{flavor} examples"
    Spec::Rake::SpecTask.new(flavor) do |t|
      t.spec_files = FileList["spec/#{flavor}/**/*.rb"]
    end

    namespace :coverage do
      desc "Run #{flavor} examples with RCov"
      Spec::Rake::SpecTask.new(flavor) do |t|
        t.spec_files = FileList["spec/#{flavor}/**/*.rb"]
        t.rcov = true
        build_artifacts = ENV['CC_BUILD_ARTIFACTS']
        t.rcov_dir = build_artifacts.nil? ? "coverage" : "#{build_artifacts}"
        excludes = %w(^spec\/)
        if ENV['GEM_HOME']
          excludes << Regexp.escape(ENV['GEM_HOME'])
        end
        if ENV['RUBY_HOME']
          excludes << Regexp.escape(ENV['RUBY_HOME'])
        end
        t.rcov_opts = ["--exclude" , excludes.join(","),
                      "--text-summary"]
      end
    end
  end
end


# AP4R misc tools ----------------------------------------------------------------

require 'active_support'
require 'code_statistics'

desc "display code statistics"
task :stats => "release:copy_plugin" do
  CodeStatistics::TEST_TYPES.concat(["Local specs"])
  CodeStatistics.new(
                     ["Core Sources", "lib"],
                     ["Rails plugin", "rails_plugin"],
                     ["Scripts", "script"],
                     ["Local specs", "spec/local"]
                     ).to_s
end

todos_dirs = %w(lib rails_plugin spec)

desc "List TODO comments in #{todos_dirs.join(", ")} directories"
task :todos => todos_dirs.map{ |dir| "todos:#{dir}" }

namespace :todos do
  todos_dirs.each do |dir|
    desc "List TODO comments in #{dir} directory"
    task dir => "release:copy_plugin" do
      print_todos(dir)
    end
  end

  def print_todos(dir)
    FileList.new("#{dir}/**/*.*").each do |file|
      next unless FileTest.file?(file)
      next if (results = todos(file)).empty?

      puts file
      results.each{ |r|
        puts "L.#{"%4d" % r[:line]}: #{r[:msg]}  --  #{r[:date]} by #{r[:by]}"
      }
      puts
    end
  end

  def todos(file)
    pattern = /TODO\s*:?\s*(.*)\s+(\d{4}\/\d{2}\/\d{2})\s*,?(?:by)?\s*(\S+)/i

    results = []
    File.open(file, "r") do |f|
      f.each_line do |line|
        next unless pattern.match(line)
        results << {:line => f.lineno, :by => $3, :date => $2, :msg => $1.strip}
      end
    end
    results
  end

end
