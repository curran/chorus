class PostgresLikeConnection < DataSourceConnection
  class DatabaseError < Error
    def error_type
      return @error_type if @error_type
      case error_code
        when /28P../ then :INVALID_PASSWORD
        when /28.../ then :AUTHORIZATION_FAILED
        when '3D000' then :DATABASE_MISSING
        when '53300' then :TOO_MANY_CONNECTIONS
        when /42.../ then :INVALID_STATEMENT
        when /08.../ then :DATA_SOURCE_UNREACHABLE
        else :GENERIC
      end
    end

    private

    def sanitize_message(message)
      message.gsub(/(user|password)=\S*?(?=[&\s]|\Z)/, '\\1=xxxx')
        .gsub('Java::OrgPostgresqlUtil::', '')
    end

    def error_code
      if @exception.respond_to?(:get_sql_state)
        @exception.get_sql_state
      else
        @exception.wrapped_exception && @exception.wrapped_exception.respond_to?(:get_sql_state) && @exception.wrapped_exception.get_sql_state
      end
    end
  end

  class ObjectNotFound < StandardError; end
  class SqlPermissionDenied < StandardError; end

  def set_timeout(timeout, statement)
    @connection.send(:statement, statement.connection) do |timeout_statement|
      timeout_statement.execute "SET statement_timeout TO #{(timeout * 1000).to_i}"
    end
  end

  def running?(search)
    with_connection do
      find_pid_query(search).any?
    end
  end

  def kill(search)
    with_connection do |connection|
      connection.select { pg_terminate_backend(procpid) }.from(find_pid_query(search)).all
    end
  end

  def with_connection(options = {})
    # do this before creating connection, because it calls with_connection
    include_public_schema = options[:include_public_schema_in_search_path] && schema_exists?("public")

    destroy_connection_on_exit = @connection.nil?

    connect!

    if schema_name
      search_path = "SET search_path TO #{quote_identifier(schema_name)}"
      if include_public_schema
        search_path << ", public"
      end
      @connection.execute(search_path)
    end

    yield @connection

  rescue Sequel::DatabaseError => e
    raise self.class.error_class.new(e)
  ensure
    disconnect if destroy_connection_on_exit
  end

  def db_url
    "jdbc:postgresql://#{@data_source.host}:#{@data_source.port}/#{database_name}"
  end

  def db_options
    options = {}
    options.merge!({
      :jdbc_properties => {
         :sslmode => 'require'
      }
    }) if @data_source.ssl

    super.merge(options)
  end

  def support_multiple_result_sets?
    true
  end

  def create_sql_result(warnings, result_set)
    GreenplumSqlResult.new(:warnings => warnings, :result_set => result_set)
  end

  def is_hawq?
    with_connection do |connection|
      version_info = connection.fetch("SELECT version()").first[:version]
      version_info.include? "HAWQ"
    end
  end

  def self.error_class
    PostgresLikeConnection::DatabaseError
  end

  def visualization_sql_generator
    Visualization::SqlGenerator::PgLike.new
  end

  private

  def quote_identifier(identifier)
    @connection.send(:quote_identifier, identifier)
  end

  def find_pid_query(search)
    @connection.from(:pg_stat_activity).select(:procpid).where { current_query.like("%#{search}%") }.exclude { current_query.like("%procpid%") }
  end

  module DatabaseMethods
    def schemas
      with_connection { |connection| connection.fetch(SCHEMAS_SQL).map { |row| row[:schema_name] } }
    end

    def create_schema(name)
      with_connection { |connection| connection.create_schema(name) }
      true
    end

    def drop_schema(name)
      with_connection { |connection| connection.drop_schema(name, :if_exists => true) }
      true
    end

    def schema_exists?(name)
      schemas.include? name
    end

    private

    SCHEMAS_SQL = <<-SQL
      SELECT
        schemas.nspname as schema_name
      FROM
        pg_namespace schemas
      WHERE
        schemas.nspname NOT LIKE 'pg_%'
        AND schemas.nspname NOT IN ('information_schema', 'gp_toolkit', 'gpperfmon')
      ORDER BY lower(schemas.nspname)
    SQL
  end

  module InstanceMethods
    def databases
      with_connection { |connection| connection.fetch(DATABASES_SQL).map { |row| row[:database_name] } }
    end

    def version
      # if the version string looks like this:
      # PostgreSQL 9.2.15 (Greenplum Database 4.1.1.2 build 2) on i386-apple-darwin9.8.0 ...
      # then we just want "4.1.1.2"

      with_connection do |connection|
        version_string = connection.fetch("select version()").first[:version]
        version_string.match(/#{version_prefix} ([\d\.]*)/)[1]
      end
    end

    def create_database(database_name)
      with_connection { |connection| connection.execute("CREATE DATABASE #{quote_identifier(database_name)}") }
      true
    end

    private

    DATABASES_SQL = <<-SQL
      SELECT
        datname as database_name
      FROM
        pg_database
      WHERE
        datallowconn IS TRUE AND datname NOT IN ('postgres', 'template1')
        ORDER BY lower(datname) ASC
    SQL

    def version_prefix
      'PostgreSQL'
    end
  end

  module SchemaMethods
    def functions
      with_connection { |connection| connection.fetch(SCHEMA_FUNCTIONS_SQL, :schema => schema_name).all }
    end

    def disk_space_used
      with_connection { |connection| connection.fetch(SCHEMA_DISK_SPACE_QUERY, :schema => schema_name).single_value }
    end

    def create_view(view_name, query)
      with_connection { |connection| connection.create_view(view_name, query) }
      true
    end

    def create_external_table(options)
      delimiter = options[:delimiter] || ','
      with_connection do |connection|
        location_string = options[:location_url] ? "LOCATION (E'#{options[:location_url]}')" : ""
        execution_string = options[:execute] ? "EXECUTE E'#{options[:execute]}'" : ""
        table_name = %Q{"#{schema_name}"."#{options[:table_name]}"}

        connection.execute(<<-SQL)
          CREATE EXTERNAL TABLE #{table_name}
          (#{options[:columns]}) #{location_string} #{execution_string} FORMAT 'TEXT'
          (DELIMITER '#{delimiter}')
        SQL
      end
      true
    end

    def table_exists?(table_name)
      with_connection { |connection| connection.table_exists?(table_name.to_s) }
    end

    def view_exists?(view_name)
      with_connection { |connection| connection.views.map(&:to_s).include? view_name }
    end

    def analyze_table(table_name)
      execute(%Q{ANALYZE "#{schema_name}"."#{table_name}"})
    end

    def truncate_table(table_name)
      execute(%Q{TRUNCATE TABLE "#{schema_name}"."#{table_name}"})
      true
    end

    def drop_table(table_name)
      with_connection { |connection| connection.drop_table(table_name, :if_exists => true) }
      true
    end

    def validate_query(query)
      connect!

      if schema_name
        search_path = "SET search_path TO #{quote_identifier(schema_name)}"
        if schema_exists?("public")
          search_path << ", public"
        end

        @connection.execute(search_path)
      end

      @connection.synchronize do |jdbc_conn|
        jdbc_conn.auto_commit = false

        statement = jdbc_conn.prepare_statement(query)
        statement.max_rows = 1
        statement.execute_query
      end

      disconnect
      true
    rescue Java::OrgPostgresqlUtil::PSQLException => e
      raise self.class.error_class.new(e)
    rescue Sequel::DatabaseError => e
      raise self.class.error_class.new(e)
    ensure
      disconnect
    end

    def datasets(options = {})
      datasets_query(options) do |query|
        query = query.limit(options[:limit])
        query = query.order { lower(replace(relname, '_', '')) }

        query.all { |hash| hash.delete(:regclass) }
      end
    end

    def datasets_count(options = {})
      datasets_query(options) do |query|
        @connection.fetch("SELECT count(datasets.*) from (#{query.sql}) datasets").single_value
      end
    end

    def column_info(table_name, table_setup_sql)
      with_connection do |connection|
        connection.execute(table_setup_sql)
        connection.fetch(COLUMN_METADATA_QUERY, :schema => schema_name, :table => table_name).all
      end
    end

    def partitions_disk_size(table_name)
      with_connection do |connection|
        partitions = connection[:pg_partitions]
        query = partitions.where(:tablename => table_name, :schemaname => schema_name)
        query.sum { pg_total_relation_size(partitiontablename) }
      end
    end

    def metadata_for_dataset(table_name)
      with_connection do |connection|
        relations = connection.from(Sequel.as(:pg_catalog__pg_class, :relations))
        schema_query = connection.from(Sequel.as(:pg_namespace, :schemas)).where(:nspname => schema_name).select(:oid)
        relations_in_schema = relations.where(:relnamespace => schema_query)
        query = relations_in_schema.where(:relations__relname => table_name)

        # Is it a view?
        query = query.left_outer_join(:pg_views, :viewname => :relname)
        query = query.left_outer_join(:pg_stat_user_tables, :relid => :relations__oid)

        query = query.select(Sequel.as(:relations__reltuples, :row_count), Sequel.as(:relations__relname, :name),
                             Sequel.as(:pg_views__definition, :definition), Sequel.as(:relations__relnatts, :column_count),
                             Sequel.as(Sequel.function(:GREATEST, :last_analyze, :last_autoanalyze), :last_analyzed))

        query = query.select_append { obj_description(relations__oid).as('description') }

        table_type = Sequel.case({'v' => 'VIEW'}, 'BASE_TABLE', :relations__relkind)
        query = query.select_append(Sequel.as(table_type, :table_type))

        result = query.first

        if result
          result[:row_count] = result[:row_count].to_i
        end
        result
      end
    end

    def query_with_disk_size(query, connection)
      begin # try the GPDB version first
        disk_size = Sequel.case(
          [
            [Sequel.lit("position('''' in relations.relname) > 0"), 'unknown'],
            [Sequel.lit("position('\\\\' in relations.relname) > 0"), 'unknown']
          ],
          Sequel.cast(Sequel.lit("pg_total_relation_size(relations.oid)"), String)
        )

        result = query.select_append(Sequel.as(disk_size, :disk_size)).first
      rescue Sequel::DatabaseError # if the above query fails, assume we're querying HAWQ and use the equivalent HAWQ query instead
        result = query.first
        result[:disk_size] = connection.from(:"pg_aoseg__pg_aoseg_#{result[:oid]}").sum(:eof) if result
      end
      result
    end

    def primary_key_columns(table_name)
      with_connection do |connection|
        sql = <<-SQL
          SELECT attname
          FROM   (SELECT *, generate_series(1, array_upper(conkey, 1)) AS rn
          FROM   pg_constraint where conrelid = '#{quote_identifier(schema_name)}.#{quote_identifier(table_name)}'::regclass and contype='p'
          ) y, pg_attribute WHERE attrelid = '#{quote_identifier(schema_name)}.#{quote_identifier(table_name)}'::regclass::oid AND conkey[rn] = attnum ORDER by rn;
        SQL
        connection.fetch(sql).map { |row| row[:attname] }
      end
    end

    def distribution_key_columns(table_name)
      []
    end

    def create_table(table_name, table_definition, distribution_clause)
      with_connection do |connection|
        connection.execute <<-SQL
        CREATE TABLE #{quote_identifier(table_name)} (#{table_definition}) #{build_distribution_clause(distribution_clause)}
        SQL
      end
      true
    end

    def copy_table_data(destination_fullname, source_table_name, setup_sql, options = nil)
      options ||= {}
      with_connection do |connection|
        connection.execute(setup_sql)
        select_data = connection.from(source_table_name.to_sym).limit(options[:limit])
        copy_command = "INSERT INTO #{destination_fullname} (#{select_data.sql});"
        CancelableQuery.new(self, options[:check_id], options[:user]).execute(copy_command)
      end
      true
    end

    def count_rows(table_name)
      with_connection { |connection| connection.from(table_name).count }
    end

    def copy_csv(java_reader, table_name, column_names, delimiter, has_header)
      with_connection do |connection|
        connection.synchronize do |jdbc_conn|
          copy_manager = org.postgresql.copy.CopyManager.new(jdbc_conn)
          sql = "COPY \"#{table_name}\"(#{column_names.map { |c| "\"#{c}\"" }.join(', ')}) FROM STDIN WITH DELIMITER '#{delimiter}' CSV #{has_header ? 'HEADER' : ''}"
          copy_manager.copy_in(sql, java_reader)
        end
      end
    end

    private

    def database_name
      @options[:database] || @data_source.db_name
    end

    def datasets_query(options)
      with_connection do |connection|
        query = connection.from(Sequel.as(:pg_catalog__pg_class, :c)).
            select(Sequel.as(:relkind, 'type'), Sequel.as(:relname, 'name'), Sequel.as(:relhassubclass, 'master_table')).
            select_append { |o| o.`(%Q{('#{quote_identifier(schema_name)}."' || c.relname || '"')::regclass}) }.
            join(Sequel.as(:pg_catalog__pg_namespace, :n), :oid => :relnamespace, :nspname => schema_name).
            where(:c__relkind => options[:tables_only] ? 'r' : %w(r v))

        if options[:name_filter]
          query = query.where(%("relname" ILIKE '%#{::DataSourceConnection.escape_like_string(options[:name_filter])}%' ESCAPE '#{::DataSourceConnection::LIKE_ESCAPE_CHARACTER}'))
        end

        yield query.qualify
      end
    rescue self.class.error_class => e
      raise SqlPermissionDenied, e if e.message =~ /permission denied/i
      raise e
    end

    def schema_name
      @options[:schema]
    end

    def build_distribution_clause(clause)
      ''
    end

    SCHEMA_FUNCTIONS_SQL = <<-SQL
      SELECT t1.oid, t1.proname, t1.lanname, t1.rettype, t1.proargnames, (SELECT t2.typname ORDER BY inputtypeid) AS argtypes, t1.prosrc, d.description
        FROM ( SELECT p.oid,p.proname,
           CASE WHEN p.proargtypes = '' THEN NULL
               ELSE unnest(p.proargtypes)
               END as inputtype,
           now() AS inputtypeid, p.proargnames, p.prosrc, l.lanname, t.typname AS rettype
         FROM pg_proc p, pg_namespace n, pg_type t, pg_language l
         WHERE p.pronamespace = n.oid
           AND p.prolang = l.oid
           AND p.prorettype = t.oid
           AND n.nspname = :schema) AS t1
      LEFT JOIN pg_type AS t2
      ON t1.inputtype = t2.oid
      LEFT JOIN pg_description AS d ON t1.oid = d.objoid
      ORDER BY t1.oid;
    SQL

    SCHEMA_DISK_SPACE_QUERY = <<-SQL
      SELECT sum(pg_total_relation_size(pg_catalog.pg_class.oid))::bigint AS size
      FROM   pg_catalog.pg_class
      LEFT JOIN pg_catalog.pg_namespace ON relnamespace = pg_catalog.pg_namespace.oid
      WHERE  pg_catalog.pg_namespace.nspname = :schema
    SQL

    COLUMN_METADATA_QUERY = <<-SQL
    SELECT a.attname, format_type(a.atttypid, a.atttypmod), des.description, a.attnum,
           s.null_frac, s.n_distinct, s.most_common_vals, s.most_common_freqs, s.histogram_bounds,
           c.reltuples
      FROM pg_attribute a
      LEFT JOIN pg_description des
        ON a.attrelid = des.objoid AND a.attnum = des.objsubid
      LEFT JOIN pg_namespace n
        ON n.nspname = :schema
      LEFT JOIN pg_class c
        ON c.relnamespace = n.oid
       AND c.relname = :table
      LEFT JOIN pg_stats s
        ON s.attname = a.attname
       AND s.schemaname = n.nspname
       AND s.tablename = c.relname
      WHERE a.attrelid = ('"' || :table || '"')::regclass
      AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum;
    SQL

  end

  include DatabaseMethods
  include InstanceMethods
  include SchemaMethods
end
