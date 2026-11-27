# frozen_string_literal: true

require "erb"
require "yaml"

RSpec.describe "Sidekiq configuration" do
  let(:root) { File.expand_path("../..", __dir__) }

  def load_config(path)
    rendered = ERB.new(File.read(File.join(root, path))).result
    YAML.safe_load(rendered, permitted_classes: [Symbol], aliases: true)
  end

  it "selects Sidekiq as the production Active Job adapter" do
    production_config = File.read(File.join(root, "config/environments/production.rb"))

    expect(production_config).to include("config.active_job.queue_adapter = :sidekiq")
  end

  it "listens to each Decidim job queue used by the application" do
    queues = load_config("config/sidekiq.yml").fetch(:queues).map { |queue| queue.first.to_s }

    expect(queues).to include(
      "default",
      "delete_inactive_participants",
      "events",
      "exports",
      "mailers",
      "reminders",
      "spam_analysis",
      "translations",
      "user_report",
      "conference_diplomas"
    )
  end

  it "provides recurring task schedules for Sidekiq-Cron" do
    schedule = load_config("config/schedule.yml")

    expect(schedule.keys).to include("hourly_active_step_job", "weekly_notifications_digest_job")
    expect(schedule.fetch("hourly_active_step_job")).to include("cron" => "*/15 * * * *", "queue" => "default")

    worker_queues = load_config("config/sidekiq.yml").fetch(:queues).map { |queue| queue.first.to_s }
    scheduled_queues = schedule.values.map { |job| job.fetch("queue", "default").to_s }.uniq
    expect(scheduled_queues - worker_queues).to be_empty
  end
end
