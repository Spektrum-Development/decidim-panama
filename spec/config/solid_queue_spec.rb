# frozen_string_literal: true

require "open3"
require "json"

RSpec.describe "Production Solid Queue configuration" do
  let(:primary_url) { "postgresql://localhost/primary_spec" }
  let(:queue_url) { "postgresql://localhost/queue_spec" }
  let(:environment) do
    {
      "RAILS_ENV" => "production",
      "SECRET_KEY_BASE" => "dummy",
      "DATABASE_URL" => primary_url,
      "QUEUE_DATABASE_URL" => queue_url,
      "QUEUE_ADAPTER" => "solid_queue"
    }
  end

  def run_production(env, code)
    Open3.capture3(env, "bundle", "exec", "rails", "runner", code)
  end

  it "connects Solid Queue to the separate queue database without seeding it" do
    output, error, status = run_production(environment, <<~RUBY)
      config = SolidQueue::Record.connection_pool.db_config
      puts({ name: config.name, database: config.database, seeds: config.seeds?,
             adapter: ActiveJob::Base.queue_adapter.class.name }.to_json)
    RUBY

    expect(status.success?).to be(true), error
    expect(JSON.parse(output)).to include(
      "name" => "queue",
      "database" => "queue_spec",
      "seeds" => false,
      "adapter" => "ActiveJob::QueueAdapters::SolidQueueAdapter"
    )
  end

  it "rejects a missing or empty queue database URL" do
    [nil, ""].each do |url|
      _, error, status = run_production(environment.merge("QUEUE_DATABASE_URL" => url), "puts 'booted'")
      expect(status.success?).to be(false)
      expect(error).to include("QUEUE_DATABASE_URL must be set")
    end
  end

  it "rejects the primary URL as the queue URL" do
    _, error, status = run_production(environment.merge("QUEUE_DATABASE_URL" => primary_url), "puts 'booted'")
    expect(status.success?).to be(false)
    expect(error).to include("QUEUE_DATABASE_URL must refer to a separate database")
  end
end
