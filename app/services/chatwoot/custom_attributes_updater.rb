class Chatwoot::CustomAttributesUpdater
  def initialize(conversation, client: HTTParty)
    @conversation = conversation
    @client = client
    @host = ENV.fetch('CHATWOOT_HOST')
    @api_key = ENV.fetch('CHATWOOT_API_KEY')
  end

  def update(attrs)
    url = "https://#{@host}/api/v1/accounts/#{@conversation.account_id}/conversations/#{@conversation.display_id}/custom_attributes"
    headers = { 'Content-Type' => 'application/json', 'api_access_token' => @api_key }
    body = { custom_attributes: attrs }.to_json
    @client.post(url, headers: headers, body: body)
  rescue StandardError => e
    Rails.logger.error("[CustomAttributesUpdater] #{e.message}")
  end
end
