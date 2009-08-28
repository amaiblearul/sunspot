module Sunspot
  module Query
    #
    # Encapsulates information common to all queries - in particular, keywords
    # and types.
    #
    class BaseQuery #:nodoc:
      include RSolr::Char

      attr_writer :keywords
      attr_writer :phrase_fields

      def initialize(types, setup)
        @types, @setup = types, setup
      end

      # 
      # Generate params for the base query. If keywords are specified, build
      # params for a dismax query, request all stored fields plus the score,
      # and put the types in a filter query. If keywords are not specified,
      # put the types query in the q parameter.
      #
      def to_params
        params = {}
        if @keywords
          params[:q] = @keywords
          params[:fl] = '* score'
          params[:fq] = types_phrase
          params[:qf] = query_fields
          params[:defType] = 'dismax'
          if @phrase_fields
            params[:pf] = @phrase_fields.map { |field| field.to_boosted_field }.join(' ')
          end
        else
          params[:q] = types_phrase
        end
        params
      end

      def add_fulltext_field(field_name, boost = nil)
        @fulltext_fields ||= []
        @fulltext_fields.concat(
          @setup.text_fields(field_name).map do |field|
            TextFieldBoost.new(field, boost)
          end
        )
      end

      def add_phrase_field(field_name, boost = nil)
        @phrase_fields ||= []
        @phrase_fields.concat(
          @setup.text_fields(field_name).map do |field|
            TextFieldBoost.new(field, boost)
          end
        )
      end

      private

      # 
      # Boolean phrase that restricts results to objects of the type(s) under
      # query. If this is an open query (no types specified) then it sends a
      # no-op phrase because Solr requires that the :q parameter not be empty.
      #
      # ==== Returns
      #
      # String:: Boolean phrase for type restriction
      #
      def types_phrase
        if escaped_types.length == 1 then "type:#{escaped_types.first}"
        else "type:(#{escaped_types * ' OR '})"
        end
      end

      #
      # Wraps each type in quotes to escape names of the form Namespace::Class
      #
      def escaped_types
        @escaped_types ||=
          @types.map { |type| escape(type.name)}
      end

      # 
      # Returns the names of text fields that should be queried in a keyword
      # search. If specific fields are requested, use those; otherwise use the
      # union of all fields configured for the types under search.
      #
      def query_fields
        @query_fields ||=
          begin
            fulltext_fields =
              @fulltext_fields || @setup.all_text_fields.map do |field|
                TextFieldBoost.new(field)
              end
            fulltext_fields.map do |fulltext_field|
              fulltext_field.to_boosted_field
            end.join(' ')
          end
      end
    end
  end
end
