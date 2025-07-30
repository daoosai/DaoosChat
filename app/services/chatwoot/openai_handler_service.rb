class Chatwoot::OpenaiHandlerService
  def initialize(payload)
    @payload = payload.deep_symbolize_keys
    @client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_API_KEY'))
  end

  def perform
    return unless ai_enabled?

    doc_url = custom_attrs[:google_doc_url]
    doc_text = GoogleDocs.extract_text_from_public_doc(doc_url)
    sections = GoogleDocs.parse_sections(doc_text)
    system_prompt = sections[:system_prompt]
    faq = sections[:faq]
    prompt = system_prompt.to_s
    prompt += "\n\nFAQ:\n#{faq}" if faq.present?
    reply = generate_reply(prompt, message_content)
    send_reply(reply) if reply.present?
  rescue StandardError => e
    Rails.logger.error("[OpenaiHandlerService] #{e.message}")
  end

  private

  def ai_enabled?
    @payload[:message_type] == 'incoming' &&
      @payload.dig(:sender, :type) == 'contact' &&
      custom_attrs[:ai_enabled] == true
  end

  def custom_attrs
    @payload.dig(:conversation, :custom_attributes) || {}
  end

  def message_content
    @payload[:content].to_s
  end

  def generate_reply(prompt, user_message)
    params = {
      model: ENV.fetch('OPENAI_GPT_MODEL', 'gpt-4o-mini'),
      messages: [
        { role: 'system', content: prompt },
        { role: 'user', content: user_message }
      ]
    }
    response = @client.chat(parameters: params)
    response.dig('choices', 0, 'message', 'content')
  rescue OpenAI::Error => e
    Rails.logger.error("[OpenaiHandlerService] OpenAI API Error: #{e.message}")
    nil
  end

  def send_reply(text)
    account_id = @payload.dig(:account, :id) || @payload[:account_id] ||
                 @payload.dig(:conversation, :account_id)
    conversation_id = @payload.dig(:conversation, :id)
    return unless account_id && conversation_id

    url = "https://#{ENV.fetch('CHATWOOT_HOST')}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}/messages"
    headers = {
      'Content-Type' => 'application/json',
      'api_access_token' => ENV.fetch('CHATWOOT_API_KEY')
    }
    body = { content: text, message_type: 'outgoing' }.to_json
    HTTParty.post(url, headers: headers, body: body)
  end
end
