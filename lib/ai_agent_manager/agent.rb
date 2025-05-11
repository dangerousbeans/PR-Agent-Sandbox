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
          branch_name = "agent-#{@id}-issue-#{issue_number}"
          create_branch(branch_name)
          instructions = issue.body
          patch = @codex.generate_patch(instructions, Dir.pwd, branch_name)
          apply_patch(patch)
          commit_and_push(branch_name)
          pr = @github.create_pull_request(@repo,
                                           "Resolve issue ##{issue_number}",
                                           branch_name,
                                           @base_branch,
                                           "Closes ##{issue_number}")
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

    def apply_patch(patch)
      File.write('changes.patch', patch)
      system('git apply changes.patch') or raise "Git apply failed"
    end

    def commit_and_push(branch_name)
      system('git add .')
      system("git commit -m 'Apply changes for issue'")
      system("git push origin #{branch_name}")
    end
  end
end