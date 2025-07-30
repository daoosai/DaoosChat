class Chatwoot::OpenaiHandlerJob < ApplicationJob
  queue_as :default

  def perform(payload = {})
    Chatwoot::OpenaiHandlerService.new(payload).perform
  end
end
