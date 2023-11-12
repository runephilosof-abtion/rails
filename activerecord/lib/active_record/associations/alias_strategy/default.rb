# frozen_string_literal: true

require "active_support/core_ext/string/conversions"

module ActiveRecord
  module Associations
    module AliasStrategy
      # Old Alias tracker working as in rails <= 7.1
      class Default < Base
        def aliased_table_for(reflection, _parent_reflection, table_name = nil)
          arel_table = reflection.klass.arel_table
          table_name ||= arel_table.name

          if aliases_tracker[table_name] == 0
            # If it's zero, we can have our table_name
            aliases_tracker[table_name] = 1
            arel_table = arel_table.alias(table_name) if arel_table.name != table_name
          else
            # Otherwise, we need to use an alias
            aliased_name = @connection.table_alias_for(yield)

            # Update the count
            count = aliases_tracker[aliased_name] += 1

            aliased_name = truncated_alias(aliased_name, "_#{count}") if count > 1

            arel_table = arel_table.alias(aliased_name)
          end

          arel_table
        end
      end
    end
  end
end
