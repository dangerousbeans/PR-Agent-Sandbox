require 'tmpdir'
require 'fileutils'

module AiAgentManager
  class Agent
    def initialize(id, github_client, codex_client, repo, base_branch = 'main')
      @id = id
      @github = github_client
      @codex = codex_client
      @repo = repo
      @base_branch = base_branch
    end

    # Process a GitHub issue: comment, generate patch, and create PR
    def work(issue)
      issue_number = issue.number
      puts "Agent #{@id} picked up issue ##{issue_number}"
      @github.comment_on_issue(@repo, issue_number, "Agent #{@id} is on it!")
      Dir.mktmpdir("agent_#{@id}") do |dir|
        Dir.chdir(dir) do
        clone_repo
        # Prepare instructions for the LLM
        instructions = issue.title + " " + (issue.body || "")
        # Generate a branch name via LLM if supported, else use default
        if @codex.respond_to?(:generate_branch_name)
          branch_name = @codex.generate_branch_name(instructions)
        else
          branch_name = "agent-#{@id}-issue-#{issue_number}"
        end
        create_branch(branch_name)
        # Use local codex CLI to perform the change run, capturing output
        @codex.run_codex_cli(instructions, dir, branch_name)
        # Generate commit message via LLM if supported, else use default
        if @codex.respond_to?(:generate_commit_message)
          commit_message = @codex.generate_commit_message(instructions)
        else
          commit_message = 'Apply changes for issue'
        end
        # Commit the changes and push the branch
        commit_and_push(branch_name, commit_message)
        # Prepare PR body, optionally include a summary of the patch output

        # diff output
        patch_output = `git diff origin/#{@base_branch}..#{branch_name}`

        if @codex.respond_to?(:summarize_patch_output)
          # Summarize only the last 20 lines of the patch output
          last_lines = patch_output.lines.last(20).join
          summary = @codex.summarize_patch_output(last_lines)
          pr_body = "Closes ##{issue_number}\n\nSummary of changes:\n#{summary}"
        else
          pr_body = "Closes ##{issue_number}"
        end
        pr = @github.create_pull_request(@repo,
                                         "Resolve issue ##{issue_number}",
                                         branch_name,
                                         @base_branch,
                                         pr_body)
          puts "Agent #{@id} created PR #{pr.html_url} for issue ##{issue_number}"
        end
      end
    rescue StandardError => e
      @github.comment_on_issue(@repo, issue_number, "Agent #{@id} encountered an error: #{e.message}")
    end

    private

    def clone_repo
      token = @github.access_token
      clone_url = if token && !token.empty?
                    "https://#{token}@github.com/#{@repo}.git"
                  else
                    "https://github.com/#{@repo}.git"
                  end
      system("git", "clone", clone_url, ".") or raise "Git clone failed"
    end

    def create_branch(branch_name)
      @github.create_branch(@repo, branch_name, @base_branch)
      system("git checkout -b #{branch_name}") or raise "Git checkout failed"
    end

    # Commit staged changes with a message and push the branch
    # commit_message: the commit message to use
    def commit_and_push(branch_name, commit_message)
      # Stage changes
      system('git', 'add', '.') or raise "Git add failed"
      # Commit; if no changes, abort
      unless system('git', 'commit', '-m', commit_message)
        raise "No changes to commit after applying patch"
      end
      # Push to remote
      system('git', 'push', 'origin', branch_name) or raise "Git push failed"
    end
  end
end