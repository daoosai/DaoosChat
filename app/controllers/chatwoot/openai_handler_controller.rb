class Chatwoot::OpenaiHandlerController < ActionController::API
  def create
    Chatwoot::OpenaiHandlerJob.perform_later(params.to_unsafe_h)
    head :ok
  end
end
