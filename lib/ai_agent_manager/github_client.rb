require 'octokit'

module AiAgentManager
  class GithubClient
    def initialize(access_token)
      @client = Octokit::Client.new(access_token: access_token)
    end

    def list_open_issues(repo)
      @client.issues(repo, state: 'open').select { |issue| issue.pull_request.nil? }
    end

    def comment_on_issue(repo, issue_number, body)
      @client.add_comment(repo, issue_number, body)
    end

    def create_branch(repo, branch_name, base_branch = 'main')
      ref = "heads/#{branch_name}"
      base_ref = @client.ref(repo, "heads/#{base_branch}")
      @client.create_ref(repo, ref, base_ref.object.sha)
    end

    def create_pull_request(repo, title, head, base = 'main', body = '')
      @client.create_pull_request(repo, base, head, title, body)
    end

    def issue_comment_count(repo, issue_number)
      @client.issue_comments(repo, issue_number).size
    end
  end
end