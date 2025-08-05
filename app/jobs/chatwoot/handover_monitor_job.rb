class Chatwoot::HandoverMonitorJob < ApplicationJob
  queue_as :scheduled_jobs

  REQUIRED_ENV_VARS = %w[CHATWOOT_HOST CHATWOOT_API_KEY].freeze

  def perform
    return if REQUIRED_ENV_VARS.any? { |key| ENV[key].blank? }

    Chatwoot::HandoverMonitorService.new.perform
  end
end
