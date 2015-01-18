module SchemaPlus
  module Middleware
    module Migration

      def self.insert
        SchemaMonkey::Middleware::Migration::Column.prepend Shortcuts
        SchemaMonkey::Middleware::Migration::Column.append AddForeignKeys
      end

      class Shortcuts < SchemaMonkey::Middleware::Base
        def call(env)
          fk_options = env.options[:foreign_key]

          case fk_options
          when false then ;
          when true then fk_options = {}
          end

          if fk_options != false # may be nil
            [:references, :on_update, :on_delete, :deferrable].each do |key|
              (fk_options||={}).reverse_merge!(key => env.options[key]) if env.options.has_key? key
            end
          end

          fk_options = false if fk_options and fk_options.has_key?(:references) and not fk_options[:references]

          env.options[:foreign_key] = fk_options

          continue env

        end
      end

      class AddForeignKeys < SchemaMonkey::Middleware::Base
        def call(env)
          options = env.options
          original_options = options.dup

          is_reference = (env.type == :reference)
          is_polymorphic = is_reference && options[:polymorphic]

          # usurp index creation from AR.  That's necessary to make
          # auto_index work properly
          index = options.delete(:index) unless is_polymorphic
          options[:foreign_key] = false if is_reference

          continue env

          return if is_polymorphic

          env.options = original_options

          add_foreign_keys_and_auto_index(env)

        end

        def add_foreign_keys_and_auto_index(env)

          if (reverting = env.caller.is_a?(::ActiveRecord::Migration::CommandRecorder) && env.caller.reverting)
            commands_length = env.caller.commands.length
          end

          config = (env.caller.try(:schema_plus_config) || SchemaPlus.config).foreign_keys
          fk_args = get_fk_args(env, config)

          # remove existing fk and auto-generated index in case of change of fk on existing column
          if env.operation == :change and fk_args # includes :none for explicitly off
            remove_foreign_key_if_exists(env)
            remove_auto_index_if_exists(env)
          end

          fk_args = nil if fk_args == :none

          create_index(env, fk_args, config)
          create_fk(env, fk_args) if fk_args

          if reverting
            rev = []
            while env.caller.commands.length > commands_length
              cmd = env.caller.commands.pop
              rev.unshift cmd unless cmd[0].to_s =~ /^add_/
            end
            env.caller.commands.concat rev
          end

        end

        def auto_index_name(env)
          ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.auto_index_name(env.table_name, env.column_name)
        end

        def create_index(env, fk_args, config)
          # create index if requested explicity or implicitly due to auto_index
          index = env.options[:index]
          index = { :name => auto_index_name(env) } if index.nil? and fk_args && config.auto_index?
          return unless index
          case env.caller
          when ::ActiveRecord::ConnectionAdapters::TableDefinition
            env.caller.index(env.column_name, index)
          else
            env.caller.add_index(env.table_name, env.column_name, index)
          end
        end

        def create_fk(env, fk_args)
          references = fk_args.delete(:references)
          case env.caller
          when ::ActiveRecord::ConnectionAdapters::TableDefinition
            env.caller.foreign_key(env.column_name, references.first, references.last, fk_args)
          else
            env.caller.add_foreign_key(env.table_name, env.column_name, references.first, references.last, fk_args)
          end
        end


        def get_fk_args(env, config)
          args = nil
          column_name = env.column_name.to_s
          options = env.options

          return :none if options[:foreign_key] == false

          args = options[:foreign_key]
          args ||= {} if config.auto_create? and column_name =~ /_id$/

          return nil if args.nil?

          args[:references] ||= env.table_name if column_name == 'parent_id'

          args[:references] ||= begin
                                  table_name = column_name.sub(/_id$/, '')
                                  table_name = table_name.pluralize if ::ActiveRecord::Base.pluralize_table_names
                                  table_name
                                end

          args[:references] = [args[:references], :id] unless args[:references].is_a? Array

          args[:on_update] ||= config.on_update
          args[:on_delete] ||= config.on_delete

          args
        end

        def remove_foreign_key_if_exists(env) #:nodoc:
          table_name = env.table_name.to_s
          foreign_keys = env.caller.foreign_keys(table_name)
          fk = foreign_keys.detect { |fk| fk.table_name == table_name && fk.column_names == Array(env.column_name).collect(&:to_s) }
          env.caller.remove_foreign_key(table_name, fk.column_names, fk.references_table_name, fk.references_column_names) if fk
        end

        def remove_auto_index_if_exists(env)
          env.caller.remove_index(env.table_name, :name => auto_index_name(env), :column => env.column_name, :if_exists => true)
        end

      end

    end
  end
end

