# frozen_string_literal: true

require "json"
require "sinatra/base"
require_relative "models/book"

class App < Sinatra::Base
  configure do
    set :bind, "0.0.0.0"
    set :port, ENV.fetch("PORT", 4567)
    set :views, File.expand_path("views", __dir__)
  end

  helpers {}

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
    Book.ensure_index!
    Book.ensure_table!

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
      book = Book.create(payload.merge(created_at: Time.now, updated_at: Time.now))
      Book.index_document!(book)
      redirect "/books/new?notice=登録しました"
    rescue StandardError => e
      status 500
      erb :"books/new", locals: { notice: nil, error: "登録に失敗しました: #{e.message}" }
    end
  end

  get "/books/search" do
    Book.ensure_index!
    Book.ensure_table!

    query = params[:q].to_s.strip
    results = []

    if !query.empty?
      begin
        results = Book.search(query).map do |entry|
          record = entry[:record]
          {
            id: entry[:id],
            score: entry[:score],
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
    Book.ensure_index!
    Book.ensure_table!

    body = request.body.read
    payload = body.empty? ? {} : JSON.parse(body)
    title = payload["title"].to_s.strip
    author = payload["author"].to_s.strip

    if title.empty? || author.empty?
      status 422
      return { error: "title and author are required" }.to_json
    end

    begin
      book = Book.create(
        title: title,
        author: author,
        description: payload["description"],
        published_year: payload["published_year"],
        created_at: Time.now,
        updated_at: Time.now
      )
      Book.index_document!(book, body_override: payload)
      status 201
      { result: "created" }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end
  end

  get "/api/books/search" do
    content_type :json
    Book.ensure_index!
    Book.ensure_table!

    query = params[:q].to_s.strip
    return { results: [] }.to_json if query.empty?

    begin
      results = Book.search(query).map do |entry|
        entry[:record].values.merge("_id" => entry[:id], "_score" => entry[:score])
      end
      { results: results }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end
  end

  post "/api/books/reset" do
    content_type :json

    begin
      new_index = Book.reset_index!
      { result: "reindexed", index: new_index }.to_json
    rescue StandardError => e
      status 500
      { error: "reindex failed: #{e.message}" }.to_json
    end
  end
end
