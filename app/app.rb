# frozen_string_literal: true

require "json"
require "sinatra/base"
require_relative "services/search_client"
require_relative "services/database"

class App < Sinatra::Base
  configure do
    set :bind, "0.0.0.0"
    set :port, ENV.fetch("PORT", 4567)
    set :views, File.expand_path("views", __dir__)
  end

  helpers do
    def search_client
      @search_client ||= Services::SearchClient.build
    end

    def db
      Services::Database.connection
    end

    def books_index
      ENV.fetch("BOOKS_INDEX", "books")
    end

    def ensure_books_index!
      return if @books_index_ready

      unless search_client.indices.exists?(index: books_index)
        search_client.indices.create(
          index: books_index,
          body: {
            mappings: {
              properties: {
                title: { type: "text" },
                author: { type: "text" },
                description: { type: "text" },
                published_year: { type: "integer" }
              }
            }
          }
        )
      end

      @books_index_ready = true
    end

    def ensure_books_table!
      return if @books_table_ready

      Services::Database.ensure_books_table!
      @books_table_ready = true
    end
  end

  get "/" do
    redirect "/books/search"
  end

  get "/health" do
    content_type :json
    { status: "ok", opensearch_url: ENV["OPENSEARCH_URL"] }.to_json
  end

  # --- UI ---
  get "/books/new" do
    erb :"books/new", locals: { notice: params[:notice], error: params[:error] }
  end

  post "/books" do
    ensure_books_index!
    ensure_books_table!

    payload = {
      title: params[:title].to_s.strip,
      author: params[:author].to_s.strip,
      description: params[:description].to_s.strip,
      published_year: params[:published_year].to_s.strip
    }.compact

    if payload[:title].empty? || payload[:author].empty?
      status 422
      return erb :"books/new", locals: { notice: nil, error: "タイトルと著者は必須です。" }
    end

    payload[:published_year] = payload[:published_year].to_i if payload[:published_year] && !payload[:published_year].empty?
    payload.delete(:published_year) if payload[:published_year].respond_to?(:zero?) && payload[:published_year].zero?
    payload.delete(:description) if payload[:description].empty?

    begin
      now = Time.now
      id = db[:books].insert(payload.merge(created_at: now, updated_at: now))
      search_client.index(index: books_index, id: id, body: payload)
      redirect "/books/new?notice=登録しました"
    rescue StandardError => e
      status 500
      erb :"books/new", locals: { notice: nil, error: "登録に失敗しました: #{e.message}" }
    end
  end

  get "/books/search" do
    ensure_books_index!
    ensure_books_table!

    query = params[:q].to_s.strip
    results = []

    if !query.empty?
      begin
        search_response = search_client.search(
          index: books_index,
          body: {
            query: {
              multi_match: {
                query: query,
                fields: %w[title^3 author description]
              }
            }
          }
        )

        hits = search_response.fetch("hits", {}).fetch("hits", [])
        ids = hits.map { |h| h["_id"].to_i }.uniq
        db_records = db[:books].where(id: ids).all.inject({}) { |acc, r| acc[r[:id]] = r; acc }

        results = hits.filter_map do |hit|
          id = hit["_id"].to_i
          record = db_records[id]
          next unless record

          {
            id:,
            score: hit["_score"],
            title: record[:title],
            author: record[:author],
            description: record[:description],
            published_year: record[:published_year]
          }
        end
      rescue StandardError => e
        status 500
        return erb :"books/search", locals: { query:, results: [], error: "検索に失敗しました: #{e.message}" }
      end
    end

    erb :"books/search", locals: { query:, results:, error: nil }
  end

  # --- JSON APIs ---
  post "/api/books" do
    content_type :json
    ensure_books_index!
    ensure_books_table!

    body = request.body.read
    payload = body.empty? ? {} : JSON.parse(body)
    title = payload["title"].to_s.strip
    author = payload["author"].to_s.strip

    if title.empty? || author.empty?
      status 422
      return { error: "title and author are required" }.to_json
    end

    begin
      now = Time.now
      id = db[:books].insert(
        title: title,
        author: author,
        description: payload["description"],
        published_year: payload["published_year"],
        created_at: now,
        updated_at: now
      )
      search_client.index(index: books_index, id: id, body: payload)
      status 201
      { result: "created" }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end
  end

  get "/api/books/search" do
    content_type :json
    ensure_books_index!
    ensure_books_table!

    query = params[:q].to_s.strip
    return { results: [] }.to_json if query.empty?

    begin
      response = search_client.search(
        index: books_index,
        body: {
          query: {
            multi_match: {
              query: query,
              fields: %w[title^3 author description]
            }
          }
        }
      )

      hits = response.fetch("hits", {}).fetch("hits", [])
      ids = hits.map { |h| h["_id"].to_i }.uniq
      db_records = db[:books].where(id: ids).all.index_by { |r| r[:id] }

      results = hits.filter_map do |hit|
        id = hit["_id"].to_i
        record = db_records[id]
        next unless record

        record.merge("_id" => id, "_score" => hit["_score"])
      end

      { results: results }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end
  end
end
