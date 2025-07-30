class Chatwoot::HandoverMonitorService
  def initialize(client: HTTParty)
    @client = client
    @host = ENV.fetch('CHATWOOT_HOST')
    @api_key = ENV.fetch('CHATWOOT_API_KEY')
    @timeout = ENV.fetch('AI_HANDOVER_TIMEOUT_MINUTES', '10').to_i
  end

  def perform
    conversations.find_each do |conversation|
      process(conversation)
    end
  rescue StandardError => e
    Rails.logger.error("[HandoverMonitorService] #{e.message}")
  end

  private

  def conversations
    Conversation.where("custom_attributes->>'ai_disabled' = 'true'")
  end

  def process(conversation)
    timestamp = conversation.custom_attributes['ai_last_user_activity_at']
    return if timestamp.blank?

    last_activity = begin
      Time.iso8601(timestamp)
    rescue StandardError
      nil
    end
    return if last_activity.nil?
    return if Time.current.utc - last_activity < @timeout.minutes

    enable_ai(conversation)
  rescue StandardError => e
    Rails.logger.error("[HandoverMonitorService] #{e.message}")
  end

  def enable_ai(conversation)
    url = "https://#{@host}/api/v1/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}/custom_attributes"
    headers = { 'Content-Type' => 'application/json', 'api_access_token' => @api_key }
    body = { custom_attributes: { ai_disabled: false } }.to_json
    @client.post(url, headers: headers, body: body)
  end
end
