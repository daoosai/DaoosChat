class Chatwoot::HandoverMonitorJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Chatwoot::HandoverMonitorService.new.perform
  end
end
