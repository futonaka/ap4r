require "#{File.dirname(__FILE__)}/ap4r_test_helper"

require 'net/http'

# Test cases with ap4r integration.
# some comments:
# - Clearance of data in a database and queues should be included.
# - Workspaces of ap4r and rails should have some conventions for convinience.
# - Think about transition to RSpec.
# - HTTP session holding support is needed
class HelloWorldStoriesTest < Test::Unit::TestCase

  def test_http_dispatch
    ap4r_helper.stop_dispatchers
    assert_one_line_added do
      say_hello(:via => :http)
    end

    ap4r_helper.start_dispatchers
    assert_one_line_added do
      join_async_world
    end
  end

  def test_http_dispatch_with_saf
    ap4r_helper.stop_dispatchers
    assert_one_line_added do
      say_hello(:with => :saf)
    end

    ap4r_helper.start_dispatchers
    assert_one_line_added do
      join_async_world
    end
  end

  private

  # Requests to <tt>sync_hello/execute_via_*</tt>.
  # Implemented by using net/http, not by +post+ method of rails integration test.
  # There's plenty of scope for refinement.
  def say_hello(options)
    via_option = options[:via] ? "_via_#{options[:via].to_s.downcase}" : ""
    with_option = options[:with] ? "_with_#{options[:with].to_s.downcase}" : ""

    Net::HTTP.start("localhost", 3000) do |http|
      http.request_post("/sync_hello/execute#{via_option}#{with_option}",
                        "sleep=0.5")
    end
  end

  # Waits for async logic to finish.
  def join_async_world
    ap4r_helper.wait_all_done
  end

  # returns line count of <tt>HelloWorld.txt</tt> file
  def line_count
    `wc -l public/HelloWorld.txt`.to_i
  end

  def assert_lines_added(added_lines)
    initial = line_count
    yield
    assert_equal (initial + added_lines), line_count
  end

  def assert_one_line_added(&block)
    assert_lines_added(1, &block)
  end

end
