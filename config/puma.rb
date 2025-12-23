# frozen_string_literal: true

port ENV.fetch("PORT", 4567)
bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 4567)}"

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count)
threads min_threads_count, max_threads_count

environment ENV.fetch("RACK_ENV", "development")
