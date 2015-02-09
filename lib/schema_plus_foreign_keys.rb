require 'active_record'
require 'valuable'

require 'schema_plus_foreign_keys/version'
require 'schema_plus_foreign_keys/active_record/base'
require 'schema_plus_foreign_keys/active_record/connection_adapters/abstract_adapter'
require 'schema_plus_foreign_keys/active_record/connection_adapters/table_definition'
require 'schema_plus_foreign_keys/active_record/schema'
require 'schema_plus_foreign_keys/active_record/connection_adapters/foreign_key_definition'
require 'schema_plus_foreign_keys/active_record/migration/command_recorder'
require 'schema_plus_foreign_keys/middleware/dumper'
require 'schema_plus_foreign_keys/middleware/migration'
require 'schema_plus_foreign_keys/middleware/model'
require 'schema_plus_foreign_keys/middleware/sql'

module SchemaPlusForeignKeys
  module ActiveRecord
    module ConnectionAdapters
      autoload :Mysql2Adapter, 'schema_plus_foreign_keys/active_record/connection_adapters/mysql2_adapter'
      autoload :PostgresqlAdapter, 'schema_plus_foreign_keys/active_record/connection_adapters/postgresql_adapter'
      autoload :Sqlite3Adapter, 'schema_plus_foreign_keys/active_record/connection_adapters/sqlite3_adapter'
    end
  end

  # This global configuation options for SchemaPlusForeignKeys.
  # Set them in +config/initializers/schema_plus_foreign_keys.rb+ using:
  #
  #    SchemaPlusForeignKeys.setup do |config|
  #       ...
  #    end
  #
  class Config < Valuable

    ##
    # :attr_accessor: auto_create
    #
    # Whether to automatically create foreign key constraints for columns
    # suffixed with +_id+.  Boolean, default is +true+.
    has_value :auto_create, :klass => :boolean, :default => true

    ##
    # :attr_accessor: auto_index
    #
    # Whether to automatically create indexes when creating foreign key constraints for columns.
    # Boolean, default is +true+.
    has_value :auto_index, :klass => :boolean, :default => true

    ##
    # :attr_accessor: on_update
    #
    # The default value for +:on_update+ when creating foreign key
    # constraints for columns.  Valid values are as described in
    # ForeignKeyDefinition, or +nil+ to let the database connection use
    # its own default.  Default is +nil+.
    has_value :on_update

    ##
    # :attr_accessor: on_delete
    #
    # The default value for +:on_delete+ when creating foreign key
    # constraints for columns.  Valid values are as described in
    # ForeignKeyDefinition, or +nil+ to let the database connection use
    # its own default.  Default is +nil+.
    has_value :on_delete

    def merge(opts)
      dup.update_attributes(opts)
    end
  end


  # Returns the global configuration, i.e., the singleton instance of Config
  def self.config
    @config ||= Config.new
  end

  # Initialization block is passed a global Config instance that can be
  # used to configure SchemaPlusForeignKeys behavior.  E.g., if you want to disable
  # automation creation of foreign key constraints for columns name *_id,
  # put the following in config/initializers/schema_plus_foreign_keys.rb :
  #
  #    SchemaPlusForeignKeys.setup do |config|
  #       config.auto_create = false
  #    end
  #
  def self.setup # :yields: config
    yield config
  end

end

SchemaMonkey.register(SchemaPlusForeignKeys)
