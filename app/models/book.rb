# frozen_string_literal: true

require_relative "base"

class Book < BaseModel
  set_dataset :books

  class << self
    def create_table_definition(db)
      db.create_table table_name do
        primary_key :id
        String :title, null: false
        String :author, null: false
        String :description, text: true
        Integer :published_year
        DateTime :created_at
        DateTime :updated_at
      end
    end

    def index_template
      {
        mappings: {
          properties: {
            title: { type: "text" },
            author: { type: "text" },
            description: { type: "text" },
            published_year: { type: "integer" }
          }
        }
      }
    end

    def index_body(record)
      {
        title: record[:title],
        author: record[:author],
        description: record[:description],
        published_year: record[:published_year]
      }
    end

    def search_body(query)
      {
        query: {
          multi_match: {
            query: query,
            fields: %w[title^3 author description]
          }
        }
      }
    end
  end
end
