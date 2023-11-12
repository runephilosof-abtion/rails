# frozen_string_literal: true

require "active_support/core_ext/string/conversions"

module ActiveRecord
  module Associations
    # Provides sql alias names to ActiveRecord::Associations::JoinDependency
    module AliasStrategy
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Consistent
        autoload :Default
        autoload :TableName
      end

      class << self
        # joins is an array of arel joins which might conflict with the aliases we assign here
        def create(connection, initial_table_name, joins, aliases_tracker = nil)
          aliases_tracker = aliases_tracker(connection, initial_table_name, joins, aliases_tracker)
          strategy_class = self.const_get(strategy.to_s.classify) ||
            raise(ArgumentError, "Unknown alias strategy: #{strategy}")
          strategy_class.new(connection, aliases_tracker)
        end

        def strategy
          @strategy || :default
        end

        attr_writer :strategy

        def aliases_tracker(connection, initial_table_name, joins, aliases_tracker = nil)
          aliases_tracker ||= Hash.new
          if joins.empty?
            aliases_tracker.default_proc ||= proc { |h, k| h[k] = 0 }
          else
            if (default_proc = aliases_tracker.default_proc)
              aliases_tracker.default_proc = proc { |h, k|
                h[k] = initial_count_for(connection, k, joins) + default_proc.call(h, k)
              }
            else
              aliases_tracker.default_proc = proc { |h, k|
                h[k] = initial_count_for(connection, k, joins)
              }
            end
          end
          aliases_tracker[initial_table_name] = 1 if aliases_tracker[initial_table_name] == 0
          aliases_tracker
        end

        def initial_count_for(connection, name, joins)
          quoted_name = nil

          counts = joins.map do |join|
            if join.is_a?(Arel::Nodes::StringJoin)
              # quoted_name should be case ignored as some database adapters (Oracle) return quoted name in uppercase
              quoted_name ||= connection.quote_table_name(name)

              # Table names + table aliases
              join.left.scan(
                /JOIN(?:\s+\w+)?\s+(?:\S+\s+)?(?:#{quoted_name}|#{name})\sON/i
              ).size
            elsif join.is_a?(Arel::Nodes::Join)
              join.left.name == name ? 1 : 0
            else
              raise ArgumentError, "joins list should be initialized by list of Arel::Nodes::Join"
            end
          end

          counts.sum
        end
      end

      class Base
        attr_reader :aliases_tracker

        def initialize(connection, aliases_tracker)
          @aliases_tracker = aliases_tracker
          @connection = connection
        end

        # the block is for the Default to support old aliases naming context dependant
        def aliased_table_for(reflection, parent_reflection, table_name = nil, &block)
          raise NotImplementedError
        end

        private
          def truncated_alias(name, suffix)
            name.slice(0, @connection.table_alias_length - suffix.length).concat(suffix)
          end
      end
    end
  end
end
