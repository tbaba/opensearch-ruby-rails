# frozen_string_literal: true

require "json"
require "sinatra/base"
require_relative "services/search_client"

class App < Sinatra::Base
  configure do
    set :bind, "0.0.0.0"
    set :port, ENV.fetch("PORT", 4567)
  end

  get "/" do
    "Sinatra skeleton ready for OpenSearch integration."
  end

  get "/health" do
    content_type :json
    { status: "ok", opensearch_url: ENV["OPENSEARCH_URL"] }.to_json
  end
end
