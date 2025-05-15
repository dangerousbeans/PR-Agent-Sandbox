require 'open3'
require 'json'
require 'openai'

module AiAgentManager
  class CodexClient
    # Initialize with OpenAI API key for lightweight LLM tasks
    def initialize(api_key = nil)
      @openai_client = OpenAI::Client.new(access_token: api_key)
    end

    # Execute Codex CLI to perform changes based on instructions and repository context.
    # Returns an array of output lines captured from the CLI run.
    # instructions: user issue body
    # repo_path:    path to repository
    # branch_name:  suggested branch name (provided to the CLI for context)
    def run_codex_cli(instructions, repo_path, branch_name)
      prompt = <<~PROMPT
        You are an AI coding assistant. Given the repository at #{repo_path} and user instructions, carry out the work to implement the change. Test if appropriate. Commit once done.
        ### Instructions:
        #{instructions}
      PROMPT

      output_lines = []
      Dir.chdir(repo_path) do
        # Use full-auto mode to automatically approve both edits and commands for non-interactive runs
        Open3.popen2e('codex', '--dangerouslyAutoApproveEverything', '-q', prompt) do |_in, stdout_err, wait_thr|
          stdout_err.each do |line|
            $stdout.print line
            output_lines << line.chomp
          end

          status = wait_thr.value
          unless status.success?
            raise "Codex CLI failed (exit #{status.exitstatus})"
          end
        end
      end
      output_lines
    end

    # Generate a concise, hyphen-separated git branch name based on task instructions using OpenAI
    def generate_branch_name(instructions)
      system_prompt = 'You are an AI assistant that suggests concise, hyphen-separated git branch names. Only return the branch name. Just one.'
      response = @openai_client.chat(
        parameters: {
          model: 'gpt-3.5-turbo',
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: instructions }
          ],
          temperature: 0.3,
          max_tokens: 10
        }
      )
      text = response.dig('choices', 0, 'message', 'content') || ''
      
      puts "Branch name: #{text}"
      text
    end

    # Generate a concise git commit message based on task instructions using OpenAI
    def generate_commit_message(instructions)
      system_prompt = 'You are an AI assistant. Write a concise commit message in imperative mood describing the requested changes.'
      response = @openai_client.chat(
        parameters: {
          model: 'gpt-3.5-turbo',
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: instructions }
          ],
          temperature: 0.3,
          max_tokens: 50
        }
      )
      text = response.dig('choices', 0, 'message', 'content') || ''
      puts "Commit message: #{text}"
      text
    end

    # Summarize the patch output using OpenAI
    # patch_lines: array of strings from codex CLI output
    def summarize_patch_output(patch_lines)
      system_prompt = 'You are an AI assistant. Summarize the changes that were applied.'
      content = patch_lines.join("\n")
      response = @openai_client.chat(
        parameters: {
          model: 'gpt-3.5-turbo',
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: content }
          ],
          temperature: 0.3,
          max_tokens: 150
        }
      )
      text = response.dig('choices', 0, 'message', 'content') || ''
      puts "Summary: #{text}"
      text
    end
  end
end
