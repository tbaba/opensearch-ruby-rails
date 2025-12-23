# frozen_string_literal: true

require "sequel"

module Services
  class Database
    class << self
      def connection
        @connection ||= Sequel.connect(
          adapter: "mysql2",
          host: ENV.fetch("DB_HOST", "mysql"),
          port: ENV.fetch("DB_PORT", 3306).to_i,
          database: ENV.fetch("DB_NAME", "books"),
          user: ENV.fetch("DB_USER", "app"),
          password: ENV.fetch("DB_PASSWORD", "password"),
          max_connections: ENV.fetch("DB_POOL", 5).to_i
        )
      end

      def ensure_books_table!
        db = connection
        return if db.table_exists?(:books)

        db.create_table :books do
          primary_key :id
          String :title, null: false
          String :author, null: false
          String :description, text: true
          Integer :published_year
          DateTime :created_at
          DateTime :updated_at
        end
      end
    end
  end
end
