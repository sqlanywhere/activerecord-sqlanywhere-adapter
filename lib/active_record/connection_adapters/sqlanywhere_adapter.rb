#====================================================
#
#    Copyright 2008-2009 iAnywhere Solutions, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                                                                               
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.
#
# While not a requirement of the license, if you do modify this file, we
# would appreciate hearing about it.   Please email sqlany_interfaces@sybase.com
#
#
#====================================================

require 'active_record/connection_adapters/abstract_adapter'

# Singleton class to hold a valid instance of the SQLAnywhereInterface across all connections
class SA
  include Singleton
  attr_accessor :api

  def initialize
    require_library_or_gem 'sqlanywhere' unless defined? SQLAnywhere
    @api = SQLAnywhere::SQLAnywhereInterface.new()
    raise LoadError, "Could not load SQLAnywhere DBCAPI library" if SQLAnywhere::API.sqlany_initialize_interface(@api) == 0 
    raise LoadError, "Could not initialize SQLAnywhere DBCAPI library" if @api.sqlany_init() == 0 
  end
end

module ActiveRecord
  class Base
    DEFAULT_CONFIG = { :username => 'dba', :password => 'sql' }
    # Main connection function to SQL Anywhere
    # Connection Adapter takes four parameters:
    # * :database (required, no default). Corresponds to "DatabaseName=" in connection string
    # * :server (optional, defaults to :databse). Corresponds to "ServerName=" in connection string 
    # * :username (optional, default to 'dba')
    # * :password (optional, deafult to 'sql')
    # * :commlinks (optional). Corresponds to "CommLinks=" in connection string
    # * :connection_name (optional). Corresponds to "ConnectionName=" in connection string
    
    def self.sqlanywhere_connection(config)

      config = DEFAULT_CONFIG.merge(config)

      raise ArgumentError, "No database name was given. Please add a :database option." unless config.has_key?(:database)

      connection_string = "ServerName=#{(config[:server] || config[:database])};DatabaseName=#{config[:database]};UserID=#{config[:username]};Password=#{config[:password]};"
      connection_string += "CommLinks=#{config[:commlinks]};" unless config[:commlinks].nil?
      connection_string += "ConnectionName=#{config[:connection_name]};" unless config[:connection_name].nil?
      connection_string += "Idle=0" # Prevent the server from disconnecting us if we're idle for >240mins (by default)

      db = SA.instance.api.sqlany_new_connection()
      
      ConnectionAdapters::SQLAnywhereAdapter.new(db, logger, connection_string)
    end
  end

  module ConnectionAdapters
    class SQLAnywhereColumn < Column
      private
        # Overridden to handle SQL Anywhere integer, varchar, binary, and timestamp types
        def simplified_type(field_type)
          return :boolean if field_type =~ /tinyint/i
          return :string if field_type =~ /varchar/i
          return :binary if field_type =~ /long binary/i
          return :datetime if field_type =~ /timestamp/i
          return :integer if field_type =~ /smallint|bigint/i
          super
        end

        def extract_limit(sql_type)
          case sql_type
            when /^tinyint/i:  1
            when /^smallint/i: 2
            when /^integer/i:  4            
            when /^bigint/i:   8  
            else super
          end
        end

      protected
        # Handles the encoding of a binary object into SQL Anywhere
        # SQL Anywhere requires that binary values be encoded as \xHH, where HH is a hexadecimal number
        # This function encodes the binary string in this format
        def self.string_to_binary(value)
          "\\x" + value.unpack("H*")[0].scan(/../).join("\\x")
        end
        
        def self.binary_to_string(value)
          value.gsub(/\\x[0-9]{2}/) { |byte| byte[2..3].hex }
        end
    end

    class SQLAnywhereAdapter < AbstractAdapter
      def initialize( connection, logger = nil, connection_string = "") #:nodoc:
        super(connection, logger)
        @auto_commit = true
        @affected_rows = 0
        @connection_string = connection_string
        connect!
      end

      def adapter_name #:nodoc:
        'SQLAnywhere'
      end

      def supports_migrations? #:nodoc:
        true
      end

      def requires_reloading?
        false
      end
   
      def active?
        # The liveness variable is used a low-cost "no-op" to test liveness
        SA.instance.api.sqlany_execute_immediate(@connection, "SET liveness = 1") == 1
      rescue
        false
      end

      def disconnect!
        result = SA.instance.api.sqlany_disconnect( @connection )
	super
      end

      def reconnect!
        disconnect!
        connect!
      end

      def supports_count_distinct? #:nodoc:
        true
      end

      def supports_autoincrement? #:nodoc:
        true
      end

      # Maps native ActiveRecord/Ruby types into SQLAnywhere types
      # TINYINTs are treated as the default boolean value
      # ActiveRecord allows NULLs in boolean columns, and the SQL Anywhere BIT type does not
      # As a result, TINYINT must be used. All TINYINT columns will be assumed to be boolean and
      # should not be used as single-byte integer columns. This restriction is similar to other ActiveRecord database drivers
      def native_database_types #:nodoc:
        {
          :primary_key => 'INTEGER PRIMARY KEY DEFAULT AUTOINCREMENT NOT NULL',
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "long varchar" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "long binary" },
          :boolean     => { :name => "tinyint"}
        }
      end

      # QUOTING ==================================================

      # Applies quotations around column names in generated queries
      def quote_column_name(name) #:nodoc:
        %Q("#{name}")
      end

      # Handles special quoting of binary columns. Binary columns will be treated as strings inside of ActiveRecord.
      # ActiveRecord requires that any strings it inserts into databases must escape the backslash (\).
      # Since in the binary case, the (\x) is significant to SQL Anywhere, it cannot be escaped.
      def quote(value, column = nil)
        case value
          when String, ActiveSupport::Multibyte::Chars
            value_S = value.to_s
            if column && column.type == :binary && column.class.respond_to?(:string_to_binary)
              "#{quoted_string_prefix}'#{column.class.string_to_binary(value_S)}'"
            else
               super(value, column)
            end
          else
            super(value, column)
        end
      end

      def quoted_true
        '1'
      end

      def quoted_false
        '0'
      end

     
      # SQL Anywhere, in accordance with the SQL Standard, does not allow a column to appear in the ORDER BY list
      # that is not also in the SELECT with when obtaining DISTINCT rows beacuse the actual semantics of this query
      # are unclear. The following functions create a query that mimics the way that SQLite and MySQL handle this query.
      #
      # This function (distinct) is based on the Oracle ActiveRecord driver created by Graham Jenkins (2005)
      # (http://svn.rubyonrails.org/rails/adapters/oracle/lib/active_record/connection_adapters/oracle_adapter.rb)
      def distinct(columns, order_by)
        return "DISTINCT #{columns}" if order_by.blank?
        order_columns = order_by.split(',').map { |s| s.strip }.reject(&:blank?)
        order_columns = order_columns.zip((0...order_columns.size).to_a).map do |c, i|
          "FIRST_VALUE(#{c.split.first}) OVER (PARTITION BY #{columns} ORDER BY #{c}) AS alias_#{i}__"
        end
        sql = "DISTINCT #{columns}, "
        sql << order_columns * ", "
      end      

      # This function (add_order_by_for_association_limiting) is based on the Oracle ActiveRecord driver created by Graham Jenkins (2005)
      # (http://svn.rubyonrails.org/rails/adapters/oracle/lib/active_record/connection_adapters/oracle_adapter.rb)    
      def add_order_by_for_association_limiting!(sql, options)
        return sql if options[:order].blank?

        order = options[:order].split(',').collect { |s| s.strip }.reject(&:blank?)
        order.map! {|s| $1 if s =~ / (.*)/}
        order = order.zip((0...order.size).to_a).map { |s,i| "alias_#{i}__ #{s}" }.join(', ')

        sql << " ORDER BY #{order}"
      end

      # The database execution function
      def execute(sql, name = nil) #:nodoc:
        return if sql.nil?
        sql = modify_limit_offset(sql)

        # ActiveRecord allows a query to return TOP 0. SQL Anywhere requires that the TOP value is a positive integer.
        return Array.new() if sql =~ /TOP 0/i
           
        # Executes the query, iterates through the results, and builds an array of hashes.
        rs = SA.instance.api.sqlany_execute_direct(@connection, sql)
        if rs.nil?
          error = SA.instance.api.sqlany_error(@connection)
          case error[0].to_i
          when -143
            if sql =~ /^SELECT/i then
              raise ActiveRecord::StatementInvalid.new("#{error}:#{sql}")
            else
              raise ActiveRecord::ActiveRecordError.new("#{error}:#{sql}")
            end
          else
            raise ActiveRecord::StatementInvalid.new("#{error}:#{sql}")
          end
        end
        
        record = []
        if( SA.instance.api.sqlany_num_cols(rs) > 0 ) 
          while SA.instance.api.sqlany_fetch_next(rs) == 1
            max_cols = SA.instance.api.sqlany_num_cols(rs)
            result = Hash.new()
            max_cols.times do |cols|
              result[SA.instance.api.sqlany_get_column_info(rs, cols)[2]] = SA.instance.api.sqlany_get_column(rs, cols)[1]
            end
            record << result
          end
          @affected_rows = 0
        else
          @affected_rows = SA.instance.api.sqlany_affected_rows(rs)
        end 
        SA.instance.api.sqlany_free_stmt(rs)

        SA.instance.api.sqlany_commit(@connection) if @auto_commit
        return record
      end

      # The database update function.         
      def update_sql(sql, name = nil)
        execute( sql, name )
        return @affected_rows
      end

      # The database delete function.
      def delete_sql(sql, name = nil) #:nodoc:
        execute( sql, name )
        return @affected_rows
      end

      # The database insert function.
      # ActiveRecord requires that insert_sql returns the primary key of the row just inserted. In most cases, this can be accomplished
      # by immediatly querying the @@identity property. If the @@identity property is 0, then passed id_value is used
      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        execute(sql, name)
        
        identity = SA.instance.api.sqlany_execute_direct(@connection, 'SELECT @@identity')
        raise ActiveRecord::StatementInvalid.new("#{SA.instance.api.sqlany_error(@connection)}:#{sql}") if identity.nil?
        SA.instance.api.sqlany_fetch_next(identity)
        retval = SA.instance.api.sqlany_get_column(identity, 0)[1]
        SA.instance.api.sqlany_free_stmt(identity)

        retval = id_value if retval == 0
        return retval
      end
      
      # Returns a query as an array of arrays
      def select_rows(sql, name = nil)
        rs = SA.instance.api.sqlany_execute_direct(@connection, sql)
        raise ActiveRecord::StatementInvalid.new("#{SA.instance.api.sqlany_error(@connection)}:#{sql}") if rs.nil?
        record = []
        while SA.instance.api.sqlany_fetch_next(rs) == 1
          max_cols = SA.instance.api.sqlany_num_cols(rs)
          result = Array.new(max_cols)
          max_cols.times do |cols|
            result[cols] = SA.instance.api.sqlany_get_column(rs, cols)[1]
          end
          record << result
        end
        SA.instance.api.sqlany_free_stmt(rs)
        return record
      end

      def begin_db_transaction #:nodoc:   
        @auto_commit = false;
      end

      def commit_db_transaction #:nodoc:
        SA.instance.api.sqlany_commit(@connection)
        @auto_commit = true;
      end

      def rollback_db_transaction #:nodoc:
        SA.instance.api.sqlany_rollback(@connection)
        @auto_commit = true;
      end

      def add_lock!(sql, options) #:nodoc:
        sql
      end

      # SQL Anywhere does not support sizing of integers based on the sytax INTEGER(size). Integer sizes
      # must be captured when generating the SQL and replaced with the appropriate size.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        if native = native_database_types[type]
          if type == :integer
            case limit
              when 1
                column_type_sql = 'tinyint'
              when 2
                column_type_sql = 'smallint'  
              when 3..4
                column_type_sql = 'integer'
              when 5..8
                column_type_sql = 'bigint'
              else
                column_type_sql = 'integer'
              end
               column_type_sql
            else
              super(type, limit, precision, scale)
          end
        else
          super(type, limit, precision, scale)
        end
      end

      # Do not return SYS-owned or DBO-owned tables
      def tables(name = nil) #:nodoc:
          sql = "SELECT table_name FROM systable WHERE creator not in (0,3)"
          select(sql, name).map { |row| row["table_name"] }
      end

      def columns(table_name, name = nil) #:nodoc:
        table_structure(table_name).map do |field|
          field['default'] = field['default'][1..-2] if (!field['default'].nil? and field['default'][0].chr == "'")
          SQLAnywhereColumn.new(field['name'], field['default'], field['domain'], (field['nulls'] == 1))
        end
      end

      def indexes(table_name, name = nil) #:nodoc:
        sql = "SELECT DISTINCT index_name, \"unique\" FROM sys.systable INNER JOIN sys.sysidxcol ON sys.systable.table_id = sys.sysidxcol.table_id INNER JOIN sys.sysidx ON sys.systable.table_id = sys.sysidx.table_id AND sys.sysidxcol.index_id = sys.sysidx.index_id WHERE table_name = '#{table_name}' AND index_category > 2"
        select(sql, name).map do |row|
          index = IndexDefinition.new(table_name, row['index_name'])
          index.unique = row['unique'] == 1
          sql = "SELECT column_name FROM sys.sysidx INNER JOIN sys.sysidxcol ON sys.sysidxcol.table_id = sys.sysidx.table_id AND sys.sysidxcol.index_id = sys.sysidx.index_id INNER JOIN sys.syscolumn ON sys.syscolumn.table_id = sys.sysidxcol.table_id AND sys.syscolumn.column_id = sys.sysidxcol.column_id WHERE index_name = '#{row['index_name']}'"	
          index.columns = select(sql).map { |col| col['column_name'] }
          index
        end
      end

      def primary_key(table_name) #:nodoc:
        sql = "SELECT sys.systabcol.column_name FROM (sys.systable JOIN sys.systabcol) LEFT OUTER JOIN (sys.sysidxcol JOIN sys.sysidx) WHERE table_name = '#{table_name}' AND sys.sysidxcol.sequence = 0"
        rs = select(sql)
        if !rs.nil? and !rs[0].nil?
          rs[0]['column_name']
        else
          nil
        end
      end

      def remove_index(table_name, options={}) #:nodoc:
        execute "DROP INDEX #{table_name}.#{quote_column_name(index_name(table_name, options))}"
      end

      def rename_table(name, new_name)
        execute "ALTER TABLE #{quote_table_name(name)} RENAME #{quote_table_name(new_name)}"
      end

      def remove_column(table_name, column_name) #:nodoc:
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP #{quote_column_name(column_name)}"
      end

      def change_column_default(table_name, column_name, default) #:nodoc:
        execute "ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} DEFAULT #{quote(default)}"
      end

      def change_column_null(table_name, column_name, null, default = nil)
        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end
        execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? '' : 'NOT'} NULL")
      end             

      def change_column(table_name, column_name, type, options = {}) #:nodoc:         
        add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(add_column_sql, options)
        add_column_sql << ' NULL' if options[:null]
        execute(add_column_sql)
      end
       
      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        execute "ALTER TABLE #{quote_table_name(table_name)} RENAME #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      end

      def remove_column(table_name, column_name)
        sql = "SELECT \"index_name\" FROM SYS.SYSTAB join SYS.SYSTABCOL join SYS.SYSIDXCOL join SYS.SYSIDX WHERE \"column_name\" = '#{column_name}' AND \"table_name\" = '#{table_name}'"
        select(sql, nil).map do |row|
          execute "DROP INDEX \"#{table_name}\".\"#{row['index_name']}\""      
        end
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP #{quote_column_name(column_name)}"
      end
         
      protected
        def select(sql, name = nil) #:nodoc:
          return execute(sql, name)
        end

        # ActiveRecord uses the OFFSET/LIMIT keywords at the end of query to limit the number of items in the result set.
        # This syntax is NOT supported by SQL Anywhere. In previous versions of this adapter this adapter simply
        # overrode the add_limit_offset function and added the appropriate TOP/START AT keywords to the start of the query.
        # However, this will not work for cases where add_limit_offset is being used in a subquery since add_limit_offset
        # is called with the WHERE clause. 
        #
        # As a result, the following function must be called before every SELECT statement against the database. It
        # recursivly walks through all subqueries in the SQL statment and replaces the instances of OFFSET/LIMIT with the
        # corresponding TOP/START AT. It was my intent to do the entire thing using regular expressions, but it would seem
        # that it is not possible given that it must count levels of nested brackets.
        def modify_limit_offset(sql)
          modified_sql = ""
          subquery_sql = ""
          in_single_quote = false
          in_double_quote = false
          nesting_level = 0
          if sql =~ /(OFFSET|LIMIT)/xmi then
            if sql =~ /\(/ then
              sql.split(//).each_with_index do |x, i|
                case x[0]
                  when 40  # left brace - (
                    modified_sql << x if nesting_level == 0
                    subquery_sql << x if nesting_level > 0
                    nesting_level = nesting_level + 1 unless in_double_quote || in_single_quote
                  when 41  # right brace - )
                    nesting_level = nesting_level - 1 unless in_double_quote || in_single_quote
                    if nesting_level == 0 and !in_double_quote and !in_single_quote then
                      modified_sql << modify_limit_offset(subquery_sql)
                      subquery_sql = ""
                    end
                    modified_sql << x if nesting_level == 0
                    subquery_sql << x if nesting_level > 0                         
                  when 39  # single quote - '
                    in_single_quote = in_single_quote ^ true unless in_double_quote
                    modified_sql << x if nesting_level == 0
                    subquery_sql << x if nesting_level > 0    
                  when 34  # double quote - "
                    in_double_quote = in_double_quote ^ true unless in_single_quote
                    modified_sql << x if nesting_level == 0
                    subquery_sql << x if nesting_level > 0
                  else
                    modified_sql << x if nesting_level == 0
                    subquery_sql << x if nesting_level > 0
                end
                raise ActiveRecord::StatementInvalid.new("Braces do not match: #{sql}") if nesting_level < 0
              end
            else
              modified_sql = sql
            end
            raise ActiveRecord::StatementInvalid.new("Quotes do not match: #{sql}") if in_double_quote or in_single_quote
            return "" if modified_sql.nil?
            select_components = modified_sql.scan(/\ASELECT\s+(DISTINCT)?(.*?)(?:\s+LIMIT\s+(.*?))?(?:\s+OFFSET\s+(.*?))?\Z/xmi)
            return modified_sql if select_components[0].nil?
            final_sql = "SELECT #{select_components[0][0]} "
            final_sql << "TOP #{select_components[0][2]} " unless select_components[0][2].nil?
            final_sql << "START AT #{(select_components[0][3].to_i + 1).to_s} " unless select_components[0][3].nil?
            final_sql << "#{select_components[0][1]}"
            return final_sql
          else
            return sql
          end
        end

        # Queries the structure of a table including the columns names, defaults, type, and nullability 
        # ActiveRecord uses the type to parse scale and precision information out of the types. As a result,
        # chars, varchars, binary, nchars, nvarchars must all be returned in the form <i>type</i>(<i>width</i>)
        # numeric and decimal must be returned in the form <i>type</i>(<i>width</i>, <i>scale</i>)
        # Nullability is returned as 0 (no nulls allowed) or 1 (nulls allowed)
        # Alos, ActiveRecord expects an autoincrement column to have default value of NULL

        def table_structure(table_name)
          sql = <<-SQL
SELECT sys.syscolumn.column_name AS name, 
  NULLIF(sys.syscolumn."default", 'autoincrement') AS "default",
  IF sys.syscolumn.domain_id IN (7,8,9,11,33,34,35,3,27) THEN
    IF sys.syscolumn.domain_id IN (3,27) THEN
      sys.sysdomain.domain_name || '(' || sys.syscolumn.width || ',' || sys.syscolumn.scale || ')'
    ELSE
      sys.sysdomain.domain_name || '(' || sys.syscolumn.width || ')'
    ENDIF
  ELSE
    sys.sysdomain.domain_name 
  ENDIF AS domain, 
  IF sys.syscolumn.nulls = 'Y' THEN 1 ELSE 0 ENDIF AS nulls
FROM 
  sys.syscolumn 
  INNER JOIN sys.systable ON sys.syscolumn.table_id = sys.systable.table_id 
  INNER JOIN sys.sysdomain ON sys.syscolumn.domain_id = sys.sysdomain.domain_id
WHERE
  table_name = '#{table_name}'
SQL
          returning structure = select(sql) do       
            raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if false
          end
        end
        
        # Required to prevent DEFAULT NULL being added to primary keys
        def options_include_default?(options)
          options.include?(:default) && !(options[:null] == false && options[:default].nil?)
        end

      private

        def connect!
          result = SA.instance.api.sqlany_connect(@connection, @connection_string)
          if result == 1 then
            set_connection_options
          else
            error = SA.instance.api.sqlany_error(@connection)
            raise ActiveRecord::ActiveRecordError.new("#{error}: Cannot Establish Connection")
          end
        end

        def set_connection_options
          SA.instance.api.sqlany_execute_immediate(@connection, "SET TEMPORARY OPTION non_keywords = 'LOGIN'") rescue nil
          SA.instance.api.sqlany_execute_immediate(@connection, "SET TEMPORARY OPTION timestamp_format = 'YYYY-MM-DD HH:NN:SS'") rescue nil
          # The liveness variable is used a low-cost "no-op" to test liveness
          SA.instance.api.sqlany_execute_immediate(@connection, "CREATE VARIABLE liveness INT") rescue nil
        end
    end
  end
end

