module SchemaDefaultExpr
  module ActiveRecord
    module ConnectionAdapters
      module MysqlAdapter
        def default_expr_valid?(expr)
          false # only the TIMESTAMP column accepts SQL column defaults and rails uses DATETIME
        end

        def sql_for_function(function)
          case function
          when :now then 'CURRENT_TIMESTAMP'
          end
        end
      end
    end
  end
end
