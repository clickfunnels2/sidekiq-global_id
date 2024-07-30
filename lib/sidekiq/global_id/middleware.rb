# frozen_string_literal: true

require_relative "serialization"

module Sidekiq
  module GlobalID
    module Middleware
      # Check if the job is an ActiveJob job
      def active_job?(job)
        job.fetch("class", "").include?("ActiveJob")
      end
    end
  end
end
