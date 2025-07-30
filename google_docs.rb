require 'net/http'
require 'uri'
module GoogleDocs
  module_function

  def extract_text_from_public_doc(doc_url)
    puts "[Google Docs] Processing URL: #{doc_url}"
    doc_id = doc_url[%r{/document/d/([a-zA-Z0-9-_]+)}, 1]
    raise ArgumentError, 'Invalid Google Doc URL' unless doc_id

    export_url = "https://docs.google.com/document/d/#{doc_id}/export?format=txt"
    puts "[Google Docs] Export URL: #{export_url}"

    uri = URI.parse(export_url)
    response = Net::HTTP.get_response(uri)
    puts "[Google Docs] Response status: #{response.code}"
    raise "Failed to fetch document. Status: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    text = response.body
    puts "[Google Docs] Received text length: #{text.length} chars"
    text
  rescue StandardError => e
    warn "[Google Docs] Error: #{e.message}"
    raise "Document fetch error: #{e.message}"
  end

  def parse_sections(text)
    sections = {}
    current = nil
    buffer = []
    text.each_line do |line|
      case line.strip
      when /^#\s*SYSTEM_PROMPT/i
        sections[current] = buffer.join("\n").strip if current
        current = :system_prompt
        buffer = []
      when /^#\s*FAQ/i
        sections[current] = buffer.join("\n").strip if current
        current = :faq
        buffer = []
      else
        buffer << line if current
      end
    end
    sections[current] = buffer.join("\n").strip if current
    { system_prompt: sections[:system_prompt], faq: sections[:faq] }
  end
end
