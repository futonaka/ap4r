class AsyncWorldController < ApplicationController

  def execute
    execute_via_http
  end

  def execute_via_http
    emulate_load(params[:sleep])
    write("World")
    render(:text => "true")
  end

  def execute_via_ws
    emulate_load
    req = params[:request]
    write("World")
    render(:text => "true")
  end

  private
  def write(message)
    open( SyncHelloController::HW_FILE, 'a' ) do |f|
      f.puts "#{message} # ...written at #{Time.now.to_s}";
    end
  end

  def emulate_load(sleep_seconds = 10)
    sleep_seconds = 10 if sleep_seconds.blank?
    sleep(sleep_seconds.to_i)
  end
end
