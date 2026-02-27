# frozen_string_literal: true

require "test_helper"

module Sidekiq
  module GlobalID
    class ClientMiddlewareTest < Minitest::Test
      include Assertions

      class TestWorker
        include Sidekiq::Worker

        def perform(_user, _name = "foo", _opts = {}, _array = []); end
      end

      def setup
        @user = Fakes::User.new
      end

      def teardown
        TestWorker.clear
      end

      attr_reader :user

      def test_serializing_positional_arguments
        enqueue(user)

        job = TestWorker.jobs.first
        arg = job["args"].first

        assert arg.start_with?("gid://")
      end

      def test_serializing_arrays_of_models
        enqueue(user, "Bilbo Baggins", { "user" => user }, [user, user])

        job = TestWorker.jobs.first
        args = job["args"].last

        args.each { |arg| assert arg.start_with?("gid://") }
      end

      def test_no_change_to_normal_strings
        enqueue(user, "Bilbo Baggins")

        job = TestWorker.jobs.first
        arg = job["args"][1]

        assert_equal "Bilbo Baggins", arg
      end

      def test_serializing_options_hashes
        enqueue(user, "Bilbo Baggins", { "user" => user, user => "1" })

        job = TestWorker.jobs.first
        options = job.dig("args", 2)
        global_id_key = options.fetch("user")

        assert global_id_key.start_with?("gid://")
        assert options.key?(String(user.to_global_id))
      end

      def test_serializing_cattr
        job = { "args" => ["test"], "cattr" => { "current_user" => user } }

        call_middleware(job)

        assert job["cattr"]["current_user"].start_with?("gid://")
      end

      def test_cattr_does_not_mutate_original_hash
        original_cattr = { "current_user" => user }
        job = { "args" => ["test"], "cattr" => original_cattr }

        call_middleware(job)

        assert_equal user, original_cattr["current_user"]
      end

      def test_no_error_when_cattr_absent
        job = { "args" => ["test"] }

        call_middleware(job)

        refute job.key?("cattr")
      end

      def test_skipping_args_serialization_for_active_job
        job = {
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [String(user.to_gid)]
        }
        original_args = job["args"].dup

        call_middleware(job)

        assert_equal original_args, job["args"]
      end

      def test_serializing_cattr_for_active_job
        job = {
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [String(user.to_gid)],
          "cattr" => { "current_user" => user }
        }

        call_middleware(job)

        assert job["cattr"]["current_user"].start_with?("gid://"),
          "cattr should be serialized even for ActiveJob jobs"
      end

      def test_yields_to_next_middleware
        job = { "args" => [] }
        yielded = false

        ClientMiddleware.new.call("TestWorker", job, "default", nil) { yielded = true }

        assert yielded
      end

      private

      def enqueue(*args)
        assert_change -> { TestWorker.jobs.size }, from: 0, to: 1 do
          TestWorker.perform_async(*args)
        end
      end

      def call_middleware(job)
        ClientMiddleware.new.call("TestWorker", job, "default", nil) {}
      end
    end
  end
end
