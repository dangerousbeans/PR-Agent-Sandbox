require 'open3'
require 'json'

module AiAgentManager
  class CodexClient
    # Initialize without remote API (using local codex CLI)
    def initialize(_api_key = nil)
      # noop: using local codex CLI instead of remote API
    end

    # Generate a git patch based on instructions and repository context by invoking local codex CLI
    # Streams output in real time to STDOUT instead of capturing it all at once.
    #
    # instructions: user issue body
    # repo_path:    path to repository
    # branch_name:  (not used here, but you could use it to name your branch/patch file)
    def generate_patch(instructions, repo_path, branch_name)
      prompt = <<~PROMPT
        You are an AI coding assistant. Given the repository at #{repo_path} and user instructions, carry out the work to implement the change. Test if appropriate. Commit once done.
        ### Instructions:
        #{instructions}
      PROMPT

      Dir.chdir(repo_path) do
        # Use full-auto mode to automatically approve both edits and commands for non-interactive runs
        Open3.popen2e('codex', '--dangerouslyAutoApproveEverything', '-q', prompt) do |stdin, stdout_err, wait_thr|
          # stream each line as it arrives
          stdout_err.each do |line|
            $stdout.print line
          end

          # check status when finished
          status = wait_thr.value
          unless status.success?
            raise "Codex CLI failed (exit #{status.exitstatus})"
          end
        end
      end
    end
  end
end
