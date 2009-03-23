class SyncHelloController < ApplicationController

  HW_FILE = File.join(RAILS_ROOT, 'public', 'HelloWorld.txt')
  FileUtils.touch(HW_FILE)

  def hello
    render :text =>"HelloWorld!"
  end


  def execute
    execute_via_http
  end

  def execute_via_http
    write('Hello')

    req = {:world_id => rand(100), :message => "World", :sleep => params[:sleep]}
    ap4r.async_to( {:controller => 'async_world', :action => 'execute_via_http'}, req )

    # The following expression is equivalent,
    #ap4r.async_to( {:url => {:controller => 'async_world', :action => 'execute_via_http'}}, req )

    # and it's possible to directly pass url as an argument.
    #ap4r.async_to( {:url => 'http://localhost:3000/async_world/execute_via_http/'}, req )

    render :nothing => true
  end

  def execute_with_block
    write('Hello')

    ap4r.async_to( {:controller => 'async_world', :action => 'execute_via_http'} ) do

      # basic
      #body :hoge, "hoge"
      #header :priority, 2

      # AR object
      #body :sm, Ap4r::StoredMessage.find(:first), :except => :id

      # by xml/http
      body :hoge, "hoge"
      body :sm, Ap4r::StoredMessage.find(:first), :except => :id
      format :xml

      # ..or explicit setting for http header
      #body :hoge, "hoge"
      #body :sm, Ap4r::StoredMessage.find(:first), :except => :id
      #http_header "Content-type", "application/x-xml"

      # directly dealing with xml message
      #body_as_xml Ap4r::StoredMessage.find(:first).to_xml(:except => :id)

      # TODO: referable, but should change longer and unique name?, 2007/5/17 kato-k
      # p @queue_name
      # p @queue_message
      # p @queue_headers
    end

    render :nothing => true
  end

  def execute_with_saf
    Ap4r::AsyncHelper::Base.saf_delete_mode = :logical
    ap4r.transaction do
      write('Hello')

      req = {:world_id => rand(100), :message => "World", :sleep => params[:sleep]}
      ap4r.async_to( {:controller => 'async_world', :action => 'execute_via_http'},
                     req)

      render :nothing => true
    end
  end

  def execute_via_xmlrpc
    write('Hello')

    req = WorldRequest.new(:world_id => rand(100), :message => "World")
    ap4r.async_to( {:controller => 'async_world', :action => 'execute_via_ws'},
                   req,
                   {:dispatch_mode => :XMLRPC} )

    render :nothing => true
  end

  def execute_via_soap
    write('Hello')

    req = WorldRequest.new(:world_id => rand(100), :message => "World")
    ap4r.async_to( {:controller => 'async_world', :action => 'execute_via_ws'},
                   req,
                   {:dispatch_mode => :SOAP} )

    render :nothing => true
  end


  def execute_via_druby
    write('Hello')

    req = { :one => 1, :two => 2 }
    # if you want to specify druby url, add the following line in configuration:
    # Ap4r::AsyncHelper::Converters::Druby = "druby://your.druby.host:port"
    ap4r.async_to({:receiver => "out", :message => 'call'},
                  req,
                  {:dispatch_mode => :druby} )
    render :nothing => true
  end

  def file_content
    render :text => read_file()
  end

  def clear_file
    File.delete(HW_FILE)
    FileUtils.touch(HW_FILE)
    render :nothing => true
  end

  def create_saf
    system("rake db:migrate;")
    render :nothing => true
  end

  def saf_content
    @stored_messages = ::Ap4r::StoredMessage.find(:all)
    render :text => @stored_messages.to_yaml
  end

  def clear_saf
    ::Ap4r::StoredMessage.destroy_all
    saf_content
  end

  private
  def write(message)
    open( HW_FILE, 'a' ) do |f|
      f.puts "#{message} # ...written at #{Time.now.to_s}";
    end
  end

  def read_file
    return "File (#{HW_FILE}) does NOT exists yet." unless File.exists?(HW_FILE)
    return IO.readlines(HW_FILE, "r").join("")
  end
end
