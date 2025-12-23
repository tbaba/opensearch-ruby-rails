# frozen_string_literal: true

require "json"
require "sinatra/base"
require_relative "services/search_client"

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
      search_client.index(index: books_index, body: payload)
      redirect "/books/new?notice=登録しました"
    rescue StandardError => e
      status 500
      erb :"books/new", locals: { notice: nil, error: "登録に失敗しました: #{e.message}" }
    end
  end

  get "/books/search" do
    ensure_books_index!

    query = params[:q].to_s.strip
    results = []

    if !query.empty?
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

        results = response.fetch("hits", {}).fetch("hits", []).map do |hit|
          source = hit["_source"]
          {
            id: hit["_id"],
            score: hit["_score"],
            title: source["title"],
            author: source["author"],
            description: source["description"],
            published_year: source["published_year"]
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

    body = request.body.read
    payload = body.empty? ? {} : JSON.parse(body)
    title = payload["title"].to_s.strip
    author = payload["author"].to_s.strip

    if title.empty? || author.empty?
      status 422
      return { error: "title and author are required" }.to_json
    end

    begin
      search_client.index(index: books_index, body: payload)
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

      hits = response.fetch("hits", {}).fetch("hits", []).map do |hit|
        hit["_source"].merge("_id" => hit["_id"], "_score" => hit["_score"])
      end

      { results: hits }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end
  end
end
