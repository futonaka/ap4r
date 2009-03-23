# In the case of laoding non-gem ap4r, make config/ap4r_spec.yml and write ap4r root dir.
# Otherwise, load gem ap4r.
#
# ap4r_spec.yml sample is following.
#
# ---
# ap4r:
#   root_dir: ~/work/svn/ap4r/trunk/ap4r
#
# TODO: integrate ap4r's root setting among several config files. 2008/02/01 by kiwamu

config_file = "./config/ap4r_spec.yml"
if File.exist?(config_file)
  require 'yaml'

  config = {}
  File.open(config_file, "r") do |input|
    YAML.load_documents(ERB.new(input.read).result) do |doc|
      config.merge! doc
    end
  end
  @test_config = config["ap4r"]
  @root_dir = @test_config["root_dir"]

  ap4r_lib_path = @root_dir + "/lib/"
  $LOAD_PATH << ap4r_lib_path
end
