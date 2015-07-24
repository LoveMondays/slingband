require 'elasticband/filter/and'
require 'elasticband/filter/not'
require 'elasticband/filter/query'
require 'elasticband/filter/term'
require 'elasticband/filter/terms'

module Elasticband
  class Filter
    PARSE_FILTERS = %i(only except includes)

    def to_h
      { match_all: {} }
    end

    class << self
      # Parses filter options to a Elasticsearch syntax
      #
      # #### Options
      #
      # * `only:` Filter the search results where the condition is `true`
      # * `except`: Filter the search results where the condition is `false`.
      # * `includes:` Filter the search results with a `Match` query.
      #
      # #### Examples
      # ```
      # Filter.parse(only: { status: :published })
      # => { term: { status: :published } }
      #
      # Filter.parse(except: { company: { id: 1 } })
      # => { not: { term: { status: :published } } }
      #
      # Filter.parse(includes: ['company', on: :description])
      # => { query: { match: { description: 'company' } } }
      # ```
      def parse(options = {})
        return {} if options.blank?

        filter = parse_filters(options[:only])
        filter += parse_filters(options[:except]).map { |f| Filter::Not.new(f) }
        filter += parse_includes_filter(options[:includes])
        join_filters(filter).to_h
      end

      private

      def join_filters(filters)
        filters.count > 1 ? Filter::And.new(filters) : filters.first
      end

      def parse_includes_filter(includes_options)
        return [] if includes_options.blank?

        [Filter::Query.new(Elasticband::Query.parse(*includes_options))]
      end

      def parse_filters(options)
        return [] if options.blank?

        to_dotted_notation(options).map { |attribute, value| parse_filter(attribute, value) }
      end

      def parse_filter(attribute, value)
        if value.is_a?(Enumerable)
          Filter::Terms.new(value, attribute)
        else
          Filter::Term.new(value, attribute)
        end
      end

      def to_dotted_notation(hash_params, prefix = nil, dotted_hash = {})
        hash_params.each_with_object(dotted_hash) do |(key, val), hash|
          if val.is_a?(Hash)
            to_dotted_notation(val, "#{prefix}#{key}.", hash)
          else
            hash["#{prefix}#{key}"] = val
          end
        end
      end
    end
  end
end
