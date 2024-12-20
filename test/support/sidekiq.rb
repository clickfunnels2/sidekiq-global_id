# frozen_string_literal: true

require "sidekiq"
require "sidekiq/testing"

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::GlobalID::ClientMiddleware
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::GlobalID::ServerMiddleware
  end
end

Sidekiq::Testing.fake!
