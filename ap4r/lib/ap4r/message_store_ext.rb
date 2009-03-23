# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

module ReliableMsg #:nodoc:
  module MessageStore #:nodoc:
    class Base

      cattr_accessor :use_mysql_extention
      @@use_mysql_extention = true

      def stale_queue targets
        queue_names = targets.split(/[\s;]/).
          select{|queue| !queue.empty? }.
          map{|queue| queue.strip! || queue }

        queue_and_created = @queues.select{|queue, messages|
          messages && (messages.size > 0) &&
          queue_names.any?{|mq|
            if mq[-1] == '*'[0]
              queue[0..(mq.size-2)] == mq[0..-2]
            else
              queue == mq
            end
          }
        }.map{|queue, messages|
          [queue, messages[0][:created]]
        }.min {|q1, q2|
          q1[1] <=> q2[1]
        }
        queue_and_created ? queue_and_created[0] : nil
      end

      # Returns a message store from the specified configuration (previously
      # created with configure).
      #
      # :call-seq:
      #   Base::configure(config, logger) -> store
      #
      def self.configure config, logger
        if config["type"].downcase.starts_with?("activerecord")
          type = config["type"].downcase.split("_").first
        else
          type = config["type"].downcase
        end
        cls = @@stores[type]
        raise RuntimeError, format(ERROR_INVALID_MESSAGE_STORE, type) unless cls
        cls.new config, logger
      end

    end

    begin

      # Make sure we have a PostgreSQL library before creating this class,
      # worst case we end up with a disk-based message store. Try the
      # native PostgreSQL library, followed by the pure Ruby PostgreSQL library.
      begin
        require 'postgres'
      rescue LoadError
        require 'postgres-pr/connection'
      end

      require 'base64'

      class PostgreSQL < Base #:nodoc:

        TYPE = self.name.split('::').last.downcase

        @@stores[TYPE] = self

        # Default prefix for tables in the database.
        DEFAULT_PREFIX = 'reliable_msg_';

        # Reference to an open PostgreSQL connection held in the current thread.
        THREAD_CURRENT_PGSQL = :reliable_msg_pgsql #:nodoc:

        def initialize config, logger
          super logger
          @config = { :host=>config['host'], :username=>config['username'], :password=>config['password'],
            :database=>config['database'], :port=>config['port'], :socket=>config['socket'] }
          @prefix = config['prefix'] || DEFAULT_PREFIX
          @queues_table = "#{@prefix}queues"
          @topics_table = "#{@prefix}topics"
        end

        def type
          TYPE
        end

        def setup
          pgsql = connection
          requires = 2 # Number of tables used by reliable-msg.
          pgsql.query "\dt" do |result|
            while row = result.fetch_row
              requires -= 1 if row[0] == @queues_table || row[0] == @topics_table
            end
          end
          if requires > 0
            sql = File.open File.join(File.dirname(__FILE__), "postgresql.sql"), "r" do |input|
              input.readlines.join
            end
            sql.gsub! DEFAULT_PREFIX, @prefix
            pgsql.query sql
            true
          end
        end


        def configuration
          config = { "type"=>TYPE, "host"=>@config[:host], "username"=>@config[:username],
            "password"=>@config[:password], "database"=>@config[:database] }
          config["port"] = @config[:port] if @config[:port]
          config["socket"] = @config[:socket] if @config[:socket]
          config["prefix"] = @config[:prefix] if @config[:prefix]
          config
        end


        def activate
          super
          load_index
        end


        def deactivate
          Thread.list.each do |thread|
            if conn = thread[THREAD_CURRENT_PGSQL]
              thread[THREAD_CURRENT_PGSQL] = nil
              conn.close
            end
          end
          super
        end


        protected

        def update inserts, deletes, dlqs
          pgsql = connection
          pgsql.query "BEGIN"
          begin
            inserts.each do |insert|
              if insert[:queue]
                pgsql.query "INSERT INTO #{@queues_table} (id,queue,headers,object) VALUES('#{connection.quote  insert[:id]}', '#{connection.quote insert[:queue]}', '#{connection.quote YAML.dump(insert[:headers])}', '#{connection.quote Base64.encode64(insert[:message])}')"
              else
                pgsql.query "REPLACE #{@topics_table} (topic,headers,object) VALUES('#{connection.quote insert[:topic]}','#{connection.quote YAML.dump(insert[:headers])}','#{connection.quote insert[:message]}')"
              end
            end
            ids = deletes.inject([]) do |array, delete|
              delete[:queue] ? array << "'#{delete[:id]}'" : array
            end
            if !ids.empty?
              pgsql.query "DELETE FROM #{@queues_table} WHERE id IN (#{ids.join ','})"
            end
            dlqs.each do |dlq|
              pgsql.query "UPDATE #{@queues_table} SET queue='#{Queue::DLQ}' WHERE id='#{connection.quote dlq[:id]}'"
            end
            pgsql.query "COMMIT"
          rescue Exception=>error
            pgsql.query "ROLLBACK"
            raise error
          end
          super
        end


        def load_index
          connection.query "SELECT id,queue,headers FROM #{@queues_table}" do |result|
            result.each do |tuple|
              queue = @queues[tuple[1]] ||= []
              headers = YAML.load tuple[2]
              # Add element based on priority, higher priority comes first.
              priority = headers[:priority]
              added = false
              queue.each_index do |idx|
                if queue[idx][:priority] < priority
                  queue[idx, 0] = headers
                  added = true
                  break
                end
              end
              queue << headers unless added
            end
          end
          connection.query "SELECT topic,headers FROM #{@topics_table}" do |result|
            result.each do |tuple|
              @topics[tuple[0]] = YAML.load tuple[1]
            end
          end
        end


        def load id, type, queue_or_topic
          message = nil
          if type == :queue
            connection.query "SELECT object FROM #{@queues_table} WHERE id='#{id}'" do |result|
              message = Base64.decode64(result[0][0]) if result[0]
            end
          else
            connection.query "SELECT object FROM #{@topics_table} WHERE topic='#{queue_or_topic}'" do |result|
              message = Base64.decode64(result[0][0]) if result[0]
            end
          end
          message
        end

        def connection
          Thread.current[THREAD_CURRENT_PGSQL] ||=
            # PGconn is overriding in this file, so is defined regardless of 'postgres' LoadError.
            if Object.const_defined? :PGError
              ::PGconn.connect @config[:host], @config[:port], @config[:options], @config[:tty], @config[:database], @config[:username], @config[:password]
            elsif Object.const_defined? :PostgresPR
              ::PostgresPR::Connection.new @config[:database], @config[:username], @config[:password], @config[:uri]
            end

        end

      end

    rescue LoadError
      # do nothing
    end


    begin
      # ActiveRecord
      # Make sure we have a ActiveRecord library before creating this class,
      # worst case we end up with a disk-based message store.
      begin
        require 'active_record'
        require 'ap4r/reliable_msg_queue'
        require 'ap4r/reliable_msg_topic'
      rescue LoadError
        require 'rubygems'
        require 'activerecord'
        require 'ap4r/reliable_msg_queue'
        require 'ap4r/reliable_msg_topic'
      end

      class ActiveRecordStore < Base #:nodoc:

        TYPE = "activerecord"

        @@stores[TYPE] = self

        # Default prefix for tables in the database.
        DEFAULT_PREFIX = 'reliable_msg_';

        # Reference to an open ActiveRecord connection held in the current thread.
        THREAD_CURRENT_ACTIVE_RECORD = :reliable_msg_active_record #:nodoc:


        def initialize config, logger
          super logger
          @config = { :adapter=>config['adapter'],
            :host=>config['host'], :username=>config['username'], :password=>config['password'],
            :database=>config['database'], :port=>config['port'], :socket=>config['socket'] }
          @prefix = config['prefix'] || DEFAULT_PREFIX
          @queues_table = "#{@prefix}queues"
          @topics_table = "#{@prefix}topics"
          establish_connection
        end


        def type
          "#{TYPE} (#{@config[:adapter]})"
        end


        # Todo: implement calling migration logic. 2007/10/01 kiwamu
        def setup
        end


        def configuration
          config = { "type"=>TYPE, "adapter"=>@config[:adapter], "host"=>@config[:host],
            "username"=>@config[:username], "password"=>@config[:password], "database"=>@config[:database] }
          config["port"] = @config[:port] if @config[:port]
          config["socket"] = @config[:socket] if @config[:socket]
          config["prefix"] = @config[:prefix] if @config[:prefix]
          config
        end


        def activate
          super
          load_index
        end


        def deactivate
          Thread.list.each do |thread|
            if conn = thread[THREAD_CURRENT_ACTIVE_RECORD]
              thread[THREAD_CURRENT_ACTIVE_RECORD] = nil
              conn.close
            end
          end
          super
        end


        protected

        def update inserts, deletes, dlqs
          begin
            inserts.each do |insert|
              if insert[:queue]
                ::Ap4r::ReliableMsgQueue.new(
                                             :message_id => insert[:id],
                                             :queue => insert[:queue],
                                             :headers => Marshal::dump(insert[:headers]),
                                             :object => insert[:message]).save!
              else
                ::Ap4r::ReliableMsgTopic.new(
                                             :topic => insert[:topic],
                                             :headers => Marshal::dump(insert[:headers]),
                                             :object => insert[:message]).save!
              end
            end
            ids = deletes.inject([]) do |array, delete|
              delete[:queue] ? array << "#{delete[:id]}" : array
            end
            if !ids.empty?
              # TODO: Use IN clause 2007/10/01 kiwamu
              ids.each do |id|
                ::Ap4r::ReliableMsgQueue.delete_all(:message_id => id)
              end
            end
            dlqs.each do |dlq|
              dlq_message = ::Ap4r::ReliableMsgQueue.find(:first, :conditions => { :message_id => dlq[:id] })
              dlq_message.queue = Queue::DLQ
              dlq_message.save!
            end
          rescue Exception=>error
            raise error
          end
          super

        end


        def load_index
          ::Ap4r::ReliableMsgQueue.find(:all).each do |message|
            queue = @queues[message[:queue]] ||= []
            headers = Marshal::load(message[:headers])
            # Add element based on priority, higher priority comes first.
            priority = headers[:priority]
            added = false
            queue.each_index do |idx|
              if queue[idx][:priority] < priority
                queue[idx, 0] = headers
                added = true
                break
              end
            end
            queue << headers unless added
          end

          ::Ap4r::ReliableMsgTopic.find(:all).each do |message|
            @topocs[message[:topic]] = Marshal::load(message[:headers])
          end
        end


        def load id, type, queue_or_topic
          object = nil
          if type == :queue
            message = ::Ap4r::ReliableMsgQueue.find(:first, :conditions => { :message_id => id })
            object = message.object
          else
            message = ::Ap4r::ReliableMsgTopic.find(:first, :conditions => { :topic => queue_or_topic })
            object = message.object
          end
          object
        end


        def establish_connection
          ActiveRecord::Base.establish_connection(
                                                  :adapter  => @config[:adapter],
                                                  :host     => @config[:host],
                                                  :username => @config[:username],
                                                  :password => @config[:password],
                                                  :database => @config[:database]
                                                  )
        end

      end

    rescue LoadError
      # do nothing
    end


    class Memory < Base #:nodoc:

      TYPE = self.name.split('::').last.downcase

      @@stores[TYPE] = self

      DEFAULT_CONFIG = {
        "type"=>TYPE,
      }

      def initialize config, logger
        super logger
        # memory_map maps messages (by ID) to memory. The value is messege object.
        @memory_map = {}
      end


      def type
        TYPE
      end


      def setup
        # do nothing
      end


      def configuration
        { "type"=>TYPE }
      end


      def activate
        super
      end


      def deactivate
        @memory_map = nil
        super
      end


      protected

      def update inserts, deletes, dlqs
        inserts.each do |insert|
          @mutex.synchronize do
            @memory_map[insert[:id]] = insert[:message]
          end
        end
        super
        @mutex.synchronize do
          deletes.each do |delete|
            @memory_map.delete(delete[:id])
          end
        end
      end

    end

  end
end

if Object.const_defined? :PGError
  class PGconn
    alias original_query query

    def query(q, *bind_values, &block)
      # In PGconn, +query+ method does NOT care about a given block.
      # To deal with a given block, this method adds iteration
      # over query results.
      maybe_result = exec(q, *bind_values)
      puts "PGconn: query called by #{q}" if $DEBUG
      puts "PGconn#query returns #{maybe_result}(class: #{maybe_result.class})." if $DEBUG
      return maybe_result unless block && maybe_result.kind_of?(PGresult)
      begin
        puts "PGconn extention: about to yield result." if $DEBUG
        block.call(maybe_result)
      ensure
        maybe_result.clear
      end
    end

    def quote str
      # do nothing
      str
    end

  end
end

if Object.const_defined? :PostgresPR
  module PostgresPR
    class Connection
      alias original_query query

      def query(q, &block)
        # In PostgresPR, +query+ method does NOT care about a given block.
        # To deal with a given block, this method adds iteration
        # over query results.
        maybe_result = original_query(q, &block)
        puts "PostgresPR: query called by #{q}" if $DEBUG
        puts "PostgresPR::Connenction#query returns #{maybe_result}(class: #{maybe_result.class})." if $DEBUG
        return maybe_result unless block && maybe_result.kind_of?(PostgresPR::Connection::Result)
        begin
          puts "PostgresPR extention: about to yield result." if $DEBUG
          block.call(maybe_result.rows)
        ensure
          maybe_result = nil
        end
      end

      def quote(str)
        # do nothing
        str
      end

    end
  end
end

if Object.const_defined?(:Mysql) && ReliableMsg::MessageStore::Base.use_mysql_extention
  class Mysql #:nodoc:
    alias original_query query

    # In Ruby/MySQL, +query+ method does NOT care about a given block.
    # To make it behave the same as MySQL/Ruby, this method adds iteration
    # over query results.
    def query(q, &block)
      maybe_result = original_query(q, &block)
      puts "Mysql extention: query called by #{q}" if $DEBUG
      puts "Mysql#query returns #{maybe_result}(class: #{maybe_result.class})." if $DEBUG
      return maybe_result unless block && maybe_result.kind_of?(Mysql::Result)
      begin
        puts "Mysql extention: about to yield result." if $DEBUG
        block.call(maybe_result)
      ensure
        maybe_result.free
      end
    end
  end
end
