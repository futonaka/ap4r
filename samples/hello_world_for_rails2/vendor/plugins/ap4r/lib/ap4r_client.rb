# Author:: Kiwamu Kato
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'forwardable'
require 'ap4r/async_helper'

module Ap4r #:nodoc:

  # This +Client+ is the Rails plugin for asynchronous processing.
  # Asynchronous logics are called via various protocols, such as XML-RPC,
  # SOAP, HTTP POST, and more. Now default protocol is HTTP POST.
  #
  # Examples: The part of calling next asynchronous logics in a controller in the HelloWorld Sample.
  #
  #     req = WorldRequest.new([:world_id => 1, :message => "World"})
  #     ap4r.async_to({:controller => 'async_world', :action => 'execute'},
  #                   {:world_id => 1, :message => "World"},
  #                   {:dispatch_mode => :HTTP}) # skippable
  #
  #     render :action => 'response'
  #
  # Complement: Above +ap4r+ method is defiend init.rb in +%RAILS_ROOT%/vendor/plugin/ap4r/+.
  #
  class Client
    extend Forwardable
    include ::Ap4r::AsyncHelper::Base

    def initialize controller
      @controller = controller
    end

    def_delegators :@controller, :logger, :url_for, :controller_path

    # Queue a message for next asynchronous logic. Some options are supported.
    #
    # Use options to specify target url, etc.
    # Accurate meanings are defined by a individual converter class.
    # * :controller (name of next logic)
    # * :action (name of next logic)
    #
    # Use rm_options to pass parameter in queue-put.
    # Listings below are AP4R extended options.
    # See the reliable-msg docuememt for more details.
    # * :target_url (URL of target, prevail over :controller)
    # * :target_action (action of target, prevail over :action)
    # * :target_method (HTTP method, e.g. "GET", "POST", etc.)
    # * :dispatch_mode (protocol in dispatching)
    # * :queue_name (prevail over :controller and :action)
    #
    # Object of argumemts (async_params, options and rm_options) will not be modified.
    # Implementors (of this class and converters) should not modify them.
    #
    # Examples: the most simple
    #
    #     ap4r.async_to({:controller => 'next_controller', :action => 'next_action'},
    #                   {:world_id => 1, :message => "World"})
    #
    #
    # Examples: taking block
    #
    #     ap4r.async_to({:controller => 'next_controller', :action => 'next_action'}) do
    #       body :world_id, 1
    #       body :message, "World"
    #     end
    #
    #
    # Examples: transmitting ActiveRecord object
    #
    #     ap4r.async_to({:controller => 'next_controller', :action => 'next_action'}) do
    #       body :world, World.find(1)
    #       body :message, "World"
    #     end
    #
    #
    # Examples: transmitting with xml format over http (now support text, json and yaml format).
    #
    #     ap4r.async_to({:controller => 'next_controller', :action => 'next_action'}) do
    #       body :world, World.find(1)
    #       body :message, "World"
    #       format :xml
    #     end
    #
    #
    # Examples: direct assignment for formatted message body
    #
    #     ap4r.async_to({:controller => 'next_controller', :action => 'next_action'}) do
    #       world = World.find(1).to_xml :except => ...
    #       body_as_xml world
    #     end
    #
    #
    # Examples: setting message header
    #
    #     ap4r.async_to({:controller => 'next_controller', :action => 'next_action'}) do
    #       body :world_id, 1
    #       body :message, "World"
    #
    #       header :priority, 1
    #       http_header "Content-type", ...
    #     end
    #
    alias :async_to :async_dispatch

    # Provides at-least-once QoS level.
    # +block+ are tipically composed of database accesses and +async_to+ calls.
    # Database accesses are executed transactionallly by +active_record_class+'s transaction method.
    # In the +block+, +async_to+ calls invoke NOT immediate queueing but just storing messages
    # to the database (assumed to be the same one as application uses).
    #
    # If the execution of +block+ finishes successfully, database transaction is committed and
    # forward process of each stored message begins.
    # Forward process composed in two parts. First puts the message into a queue, secondary update
    # or delete the entry from a management table.
    #
    # SAF (store and forward) processing like this guarantees that any message
    # is never lost and keeps reasonable performance (without two phase commit).
    #
    # Examples: Just call async_to method in this block.
    #
    #     ap4r.transaction do
    #       req = WorldRequest.new([:world_id => 1, :message => "World"})
    #       ap4r.async_to({:controller => 'async_world', :action => 'execute'},
    #                     {:world_id => 1, :message => "World"})
    #
    #       render :action => 'response'
    #     end
    #
    alias :transaction :transaction_with_saf

  end
end
