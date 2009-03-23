$VERBOSE = nil

# Load AP4R rakefile extensions
Dir["#{File.dirname(__FILE__)}/*.rake"].each { |ext| load ext }

# Load any custom rakefile extensions
#Dir["#{AP4R_ROOT}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
