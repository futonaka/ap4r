# Author:: Kiwamu Kato
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'active_record'
require 'active_support'

module Ap4r #:nodoc:

  # This +MessageBuilder+ is the class for formatting message body.
  # Current support formats are text, xml, json and yaml,
  # and the formatted messages are sent over HTTP.
  #
  # Using +format+ method, this class automatically changes the format of
  # the given message body and adds appropriate +Content-type+ to http header.
  # Or using +body_as_*+ methods, you can directly assign formatted message body.
  class MessageBuilder

    def initialize(queue_name, queue_message, queue_headers)
      @queue_name = queue_name
      @message_body = queue_message
      @message_headers = queue_headers
      @format = nil
      @message_body_with_format = nil
      @to_xml_options = {:root => "root"}
    end

    attr_accessor :queue_name, :message_body, :message_headers
    attr_reader :format, :to_xml_options

    # Sets message body in async_to block.
    # The first argument is key and the second one is value.
    #
    # options are for to_xml conversion on Array and Hash, ActiveRecord objects.
    #
    def body(k, v, options = { })
      k ||= v.class
      if v.kind_of? ActiveRecord::Base
        @message_body[k.to_sym] = v
        @to_xml_options = @to_xml_options.merge(options)
      else
        @message_body[k.to_sym] = v
      end
    end

    # Sets message header in async_to block.
    # The first argument is key and the second one is value.
    #
    # Now supports following keys:
    #   :expire
    #   :priority
    #   :delivery
    #   :max_deliveries
    #   :dispatch_mode
    #   :target_method
    #   :target_url
    #   :id
    #
    # For details, please refer the reliable-msg.
    #
    def header(k, v)
      @message_headers[k.to_sym] = v
    end

    # Sets http header in async_to block such as 'Content_type'.
    # The first argument is key and the second one is value.
    #
    def http_header(k, v)
      @message_headers["http_header_#{k}".to_sym] = v
    end

    # Sets format message serialization.
    # As to the format, automatically sets content-type.
    # Unless any format, content-type is defined as "application/x-www-form-urlencoded".
    #
    def format(v)
      case @format = v
      when :text
        set_content_type("text/plain")
      when :xml
        set_content_type("application/xml")
      when :json
        set_content_type("application/json")
      when :yaml
        set_content_type("text/yaml")
      else
        set_content_type("application/x-www-form-urlencoded")
      end
    end

    # Sets text format message. No need to use +format+.
    #
    def body_as_text(text)
      @message_body_with_format = text
      format :text
    end

    # Sets xml format message. No need to use +format+.
    #
    def body_as_xml(xml)
      @message_body_with_format = xml
      format :xml
    end

    # Sets json format message. No need to use +format+.
    #
    def body_as_json(json)
      @message_body_with_format = json
      format :json
    end

    # Sets yaml format message. No need to use +format+.
    #
    def body_as_yaml(yaml)
      @message_body_with_format = yaml
      format :yaml
    end

    # Return converted message body, as to assigned format.
    #
    def format_message_body
      return @message_body_with_format  if @message_body_with_format

      case @format
      when :text
        return @message_body.to_s
      when :xml
        return @message_body.to_xml(@to_xml_options)
      when :json
        return @message_body.to_json
      when :yaml
        return @message_body.to_yaml
      else
        @message_body.each do |k,v|
          if v.kind_of? ActiveRecord::Base
            @message_body[k] = v.attributes
          end
        end
        return query_string(@message_body)
      end
    end

    private
    def query_string(hash)
      build_query_string(hash, nil, nil)
    end

    def build_query_string(hash, query = nil, top = nil)
      query ||= []
      top ||= ""

      _top = top.dup

      hash.each do |k,v|
        top = _top
        top += top == "" ? "#{urlencode(k.to_s)}" : "[#{urlencode(k.to_s)}]"
        if v.kind_of? Hash
          build_query_string(v, query, top)
        elsif v.kind_of? Array
          v.each do |e|
            query << "#{top}[]=#{urlencode(e.to_s)}"
          end
        else
          query << "#{top}=#{urlencode(v.to_s)}"
        end
      end
      query.join('&')
    end

    def simple_url_encoded_form_data(params, sep = '&')
      params.map {|k,v| "#{urlencode(k.to_s)}=#{urlencode(v.to_s)}" }.join(sep)
    end

    def urlencode(str)
      str.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end

    def set_content_type(type)
      http_header("Content-type", type)
    end
  end
end
