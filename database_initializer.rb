# This is used for schema set up (schema,objects,grants,import .dmp files) in Oracle XE

class DatabaseInitializer

  def self.make_connection username, password
    connection_info = ActiveRecord::Base.configurations[RAILS_ENV]
    raise "Cannot perform action in non oracle environment" unless connection_info["adapter"].include? "oracle"
    ActiveRecord::Base.establish_connection({
        :adapter=> connection_info["adapter"],
        :database=> connection_info["database"],
        :username => username || connection_info["username"],
        :password => password || connection_info["password"]
      })
  end
  
  def self.get_db_char_set username, password
    make_connection username, password
    ActiveRecord::Base.connection.select_all("select value from NLS_DATABASE_PARAMETERS where parameter = 'NLS_CHARACTERSET'").first["value"]
  end

  def self.schema_exists? username, password, schema
    make_connection username, password
    ActiveRecord::Base.connection.select_all("select username from all_users where username = '#{schema.upcase}'").size == 1
  end

  def self.objects_exists? username, password, schema, min_objects_count=1
    make_connection username, password
    ActiveRecord::Base.connection.select_all("select object_name from all_objects where owner = '#{schema.upcase}'").size >= min_objects_count
  end
  
  def self.setup_local_oracle_schema change_db_charset_file_name, create_schema_file_name
    system_password  = ENV['SYSTEM_PASSWORD'] || 'system'
    Dir.chdir("#{RAILS_ROOT}/db/oracle_xe_setup/") do
      as_sysdba = true
      file_name = "#{change_db_charset_file_name}.sql"
      execute_sqlplus_start_file(file_name, "system", system_password, !as_sysdba) unless get_db_char_set("system", system_password) == "AL32UTF8"

      file_name = "#{create_schema_file_name}.sql"
      execute_sqlplus_start_file(file_name, "system", system_password, !as_sysdba) unless schema_exists?("system", system_password, "mytime")      
    end
  end
  
  def self.drop_local_oracle_schema drop_schema_file_name
    system_password  = ENV['SYSTEM_PASSWORD'] || 'system'
    Dir.chdir("#{RAILS_ROOT}/db/oracle_xe_setup/") do
      file_name = "#{drop_schema_file_name}.sql"
      execute_sqlplus_start_file file_name, "system", system_password
    end
  end    
  
  def self.parse_sql_command_file file_name, delimiter=";"
    File.open(file_name).read.split(delimiter).each do |sql|
      yield sql.strip unless sql.strip.empty?
    end
  end

  def self.execute_sql_command_file file_name, username, password, delimiter=";"
    make_connection username, password
    parse_sql_command_file(file_name, delimiter) {|sql| ActiveRecord::Base.connection.execute sql}
  end

  def self.execute_sqlplus_start_file file_name, username, password, as_sysdba=false
    connection_info = ActiveRecord::Base.configurations[RAILS_ENV]
    raise "Cannot perform action in non oracle environment" unless connection_info["adapter"].include? "oracle"

    sqlplus_command = "sqlplus #{username}/#{password}@#{connection_info["database"]} #{"as sysdba" if as_sysdba} @#{file_name}"
    p sqlplus_command
    system(sqlplus_command)
  end

  def self.import_data_file param_file_name, username, password, schema_name_to_be_imported_in, as_sysdba=false
    connection_info = ActiveRecord::Base.configurations[RAILS_ENV]
    raise "Cannot perform action in non oracle environment" unless connection_info["adapter"].include? "oracle"

    import_command = "imp #{username}/#{password} file=#{param_file_name} fromuser=#{schema_name_to_be_imported_in} touser=#{schema_name_to_be_imported_in}"
    p import_command
    system(import_command)
  end
end