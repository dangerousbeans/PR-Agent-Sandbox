require 'openai'

module AiAgentManager
  class CodexClient
    def initialize(api_key)
      @client = OpenAI::Client.new(access_token: api_key)
    end

    # Generate a git patch based on instructions and repository context
    def generate_patch(instructions, repo_path, branch_name)
      prompt = <<~PROMPT
        You are an AI coding assistant. Given the repository at #{repo_path} and user instructions, generate a git patch to implement the change.
        ### Instructions:
        #{instructions}
      PROMPT
      response = @client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            { role: "system", content: "Generate a git patch for the following instructions." },
            { role: "user", content: prompt }
          ],
          temperature: 0.2
        }
      )
      response.dig("choices", 0, "message", "content")
    end
  end
end