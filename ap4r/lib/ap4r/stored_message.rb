# Author:: Kiwamu Kato
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

begin 
  require 'active_record'
  require 'uuid'
  require 'reliable-msg'
rescue LoadError
  require 'rubygems'
  require 'activerecord'
  require 'uuid'
  require 'reliable-msg'
end

module Ap4r

  # This class is the model class for SAF(store and foward).
  # The migration file is located at following path,
  #   ap4r/lib/ap4r/xxx_create_table_for_saf.rb
  # Don't forget to create table, before use SAF.
  class StoredMessage < ActiveRecord::Base

    STATUS_STORED = 0
    STATUS_FORWARDED = 1
    @@status_value_of = { :unforwarded => STATUS_STORED,
                      :forwarded => STATUS_FORWARDED }
    
    PHYSICAL = :physical
    LOGICAL = :logical
    
    def dumped_headers
      # The warning occurs when putting backslash into binaly type in PostgreSQL.
      if self.class.postgresql?
        self.headers
      else
        Marshal::dump(self.headers)
      end      
    end
    
    def dumped_object
      # The warning occurs when putting backslash into binaly type in PostgreSQL.
      if self.class.postgresql?
        self.object
      else
        Marshal::dump(self.object)
      end      
    end
    
    # Insert queue information, such as queue name and message,  for next logic.
    #
    # duplication_check_id is generated from UUID and should be unique
    # in all records of StoreMessages. 
    # So, using this id, it's possible to protect to execute same asynchronous 
    # processing by same message.
    # But by default, record of StoreMessages is removed after putting a message 
    # into queue completed.
    #
    def self.store(queue_name, queue_message, rm_options = {})
      sm = StoredMessage.new do |s|
        s.duplication_check_id = UUID.new
        s.queue = queue_name
        s.status = STATUS_STORED

        # The warning occurs when putting backslash into binaly type in PostgreSQL.
        if postgresql?
          s.object = YAML.dump(queue_message)
          s.headers = YAML.dump(rm_options)
        else
          s.object = Marshal::dump(queue_message)
          s.headers = Marshal::dump(rm_options)
        end
      end

      begin
        sm.save!
      rescue Exception => error
        raise error
      end  
      sm
    end

    # Destroy a record by id.
    # Some options are supported.
    # * :delete_mode (:physical or :logical)
    # Default delete mmode is physical.
    # If you need logical delete, for example you neeed checking message
    # duplication etc, set the <tt>Ap4r::AsyncController.saf_delete_mode</tt>
    # <tt>:logical</tt>.
    def self.destroy_if_exists(id, options)
      result = nil
      begin
        result = StoredMessage.find(id) 
      rescue ActiveRecord::RecordNotFound
        # There are possibilities that other threads or processes have already forwarded. 
        return nil
      end
      result.destroy_or_update(options)
    end

    def self.postgresql?
      "PostgreSQL" == Ap4r::StoredMessage.connection.adapter_name
    end
    
    def destroy_or_update(options = {:delete_mode => PHYSICAL})
      case options[:delete_mode]
      when PHYSICAL
        # TODO: Confirm to raise error, 2006/10/17 kato-k 
        self.destroy
      when LOGICAL
        self.status = STATUS_FORWARDED
        self.save!
      else
        raise "unknown delete mode: #{options[:delete_mode]}"
      end
      self
    end

    # List the records which have specified status.
    # The statuses are :forwarded, :unforwarded and :all.
    # :unforwarded means unprocessed or error during forward process.
    def self.find_status_of(status = :unforwarded)
      case status
      when :all
        StoredMessage.find(:all)
      when :forwarded, :unforwarded
        StoredMessage.find(:all, :conditions => { :status => @@status_value_of[status] })
      else
        puts "Undefined status: #{status.to_s}."
        puts "Usage: Ap4r::StoredMessage.find_on [ :forwarded | :unforwarded | :all ]"
      end
    end

    # Return id, queue_name and created date time.
    def to_summary_string
      return "#{self.id}, #{self.queue}, #{self.created_at}"
    end
    
    # Update status value.
    def self.update_status(id, status)
      return "undefined status: #{status}" unless @@status_value_of.keys.include? status
      stored_message = StoredMessage.find(id)
      
      before_status = stored_message.status
      after_status = @@status_value_of[status]
      
      stored_message.status = after_status
      stored_message.save!
    end
    
    # Try to forward the ONE message which status is unforwarded.
    # If the message is forwarded successfully, the status will be "1" that means forwarded.
    def self.reforward(id)
      stored_message = StoredMessage.find(id)
      if stored_message.status == @@status_value_of[:forwarded]
        raise "The message (id = #{id}) was already forwarded." 
      end
      stored_message.forward_and_update_status
    end
    
    # Try to forward all messages which status are unforwarded.
    # This method issue commit command to database every transaction_num.
    def self.reforward_all(transaction_num = 10)
      
      stored_messages = StoredMessage.find(:all, 
                                           :conditions => {:status => @@status_value_of[:unforwarded]})
      total_num = stored_messages.size
      failed_num = 0
      
      0.step(total_num, transaction_num) do |offset|
        target_sms = stored_messages[offset..(offset + transaction_num - 1)]
        next if target_sms.empty?
        begin
          StoredMessage.transaction do
            target_sms.each do |target_sm|
              target_sm.forward_and_update_status
            end
          end
        rescue Exception => error
          puts error.message
          failed_num += target_sms.size
        end
      end
      return [total_num - failed_num, failed_num]
    end
        
    def forward_and_update_status
      queue_name     = self.queue
      
      # The warning occurs when putting backslash into binaly type in PostgreSQL.
      if self.class.postgresql?
        queue_headers  = YAML.load(self.headers)
        queue_messages = YAML.load(self.object)
      else
        queue_headers  = Marshal::load(self.headers)
        queue_messages = Marshal::load(self.object)
      end

      q = ::ReliableMsg::Queue.new(queue_name, :drb_uri => Ap4r::AsyncHelper::Base::DRUBY_URI)
      q.put(queue_messages, queue_headers)

      self.status = STATUS_FORWARDED
      self.save!
    end
    
  end
end
