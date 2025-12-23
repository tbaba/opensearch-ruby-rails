# frozen_string_literal: true

module Services
  class SearchClient
    def self.build(logger: nil)
      require "opensearch"

      url = ENV.fetch("OPENSEARCH_URL", "http://localhost:9200")
      OpenSearch::Client.new(hosts: [url], logger: logger)
    end
  end
end
