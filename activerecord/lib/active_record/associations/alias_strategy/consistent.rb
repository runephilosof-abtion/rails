# frozen_string_literal: true

require "active_support/core_ext/string/conversions"

module ActiveRecord
  module Associations
    module AliasStrategy
      # Alias names consistent with the association/relation names
      class Consistent < Base
        def aliased_table_for(reflection, parent_reflection, _table_name = nil)
          arel_table = reflection.klass.arel_table
          alias_name = reflection.name.to_s
          alias_name = "#{parent_reflection.name}_#{alias_name}" if aliases_tracker[alias_name] > 0
          count = aliases_tracker[alias_name] += 1
          arel_table = arel_table.alias(truncated_alias(alias_name, "")) if count == 1
          arel_table = arel_table.alias(truncated_alias(alias_name, "_#{count}")) if count > 1
          arel_table
        end
      end
    end
  end
end
