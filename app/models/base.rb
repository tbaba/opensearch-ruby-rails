# frozen_string_literal: true

require "sequel"
require_relative "../services/database"
require_relative "../services/search_client"

DB = Services::Database.connection
Sequel::Model.db = DB

module IndexingModel
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def db
      Sequel::Model.db
    end

    def table_name
      dataset.first_source_table
    end

    def index_name
      ENV.fetch("#{table_name.to_s.upcase}_INDEX", table_name.to_s)
    end

    def search_client
      @search_client ||= Services::SearchClient.build
    end

    def ensure_table!
      return if db.table_exists?(table_name)

      create_table_definition(db)
    end

    def ensure_index!
      return if @index_ready

      if search_client.indices.exists_alias?(name: index_name)
        @index_ready = true
        return
      end

      new_index = "#{index_name}-#{Time.now.to_i}"
      search_client.indices.create(index: new_index, body: index_template)

      if search_client.indices.exists?(index: index_name)
        search_client.indices.delete(index: index_name)
      end

      search_client.indices.update_aliases(
        body: {
          actions: [
            { add: { index: new_index, alias: index_name, is_write_index: true } }
          ]
        }
      )

      @index_ready = true
    end

    def index_document!(record, body_override: nil, client: search_client)
      body = body_override || index_body(record)
      client.index(index: index_name, id: record[:id], body: body)
    end

    def reset_index!(batch_size: ENV.fetch("#{table_name.to_s.upcase}_REINDEX_BATCH", 1000).to_i)
      ensure_table!
      new_index = "#{index_name}-#{Time.now.to_i}"

      search_client.indices.create(index: new_index, body: index_template)

      last_id = 0
      loop do
        batch = dataset.where(Sequel[:id] > last_id).order(:id).limit(batch_size).all
        break if batch.empty?

        bulk_body = batch.flat_map do |row|
          [
            { index: { _index: new_index, _id: row[:id] } },
            index_body(row)
          ]
        end

        search_client.bulk(body: bulk_body) if bulk_body.any?
        last_id = batch.last[:id]
      end

      search_client.indices.refresh(index: new_index)

      current_indices = []
      begin
        alias_info = search_client.indices.get_alias(name: index_name)
        current_indices = alias_info.keys
      rescue StandardError
        current_indices = []
      end

      actions = current_indices.map { |idx| { remove: { index: idx, alias: index_name } } }
      actions << { add: { index: new_index, alias: index_name, is_write_index: true } }
      search_client.indices.update_aliases(body: { actions: actions })

      obsolete = current_indices - [new_index]
      search_client.indices.delete(index: obsolete) if obsolete.any?

      new_index
    end

    def search(query, client: search_client)
      ensure_table!
      ensure_index!

      response = client.search(index: index_name, body: search_body(query))

      hits = response.fetch("hits", {}).fetch("hits", [])
      ids = hits.map { |h| h["_id"].to_i }.uniq
      records = where(id: ids).all.each_with_object({}) { |r, memo| memo[r[:id]] = r }

      hits.filter_map do |hit|
        id = hit["_id"].to_i
        record = records[id]
        next unless record

        { id: id, score: hit["_score"], record: record }
      end
    end

    # --- To be implemented/overridden by subclasses ---
    def create_table_definition(_db)
      raise NotImplementedError, "define create_table_definition in subclass"
    end

    def index_template
      raise NotImplementedError, "define index_template in subclass"
    end

    def index_body(_record)
      raise NotImplementedError, "define index_body in subclass"
    end

    def search_body(_query)
      raise NotImplementedError, "define search_body in subclass"
    end
  end
end

class BaseModel < Sequel::Model
  include IndexingModel
end
