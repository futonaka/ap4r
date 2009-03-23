# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require File.dirname(__FILE__) + '/../test_helper'
require 'ap4r/queue_put_stub'
require 'sync_hello_controller'

# Re-raise errors caught by the controller.
class SyncHelloController; def rescue_action(e) raise e end; end

class SyncHelloControllerTest < Test::Unit::TestCase
  def setup
    @controller = SyncHelloController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end

  def test_hello_via_http_and_async
    post :execute_via_http, {}
    assert_response 200
    assert_equal 1, @controller.ap4r.queued_messages.size
  end

end
