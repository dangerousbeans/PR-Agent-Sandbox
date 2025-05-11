require 'thread'

module AiAgentManager
  class IssueWatcher
    def initialize(github_client, repo, queue, poll_interval)
      @github_client = github_client
      @repo = repo
      @queue = queue
      @poll_interval = poll_interval
      @known_issues = {}
    end

    def start
      Thread.new do
        loop do
          issues = @github_client.list_open_issues(@repo)
          issues.each do |issue|
            unless @known_issues[issue.number]
              @known_issues[issue.number] = true
              @queue << issue
            end
          end
          sleep @poll_interval
        end
      end
    end
  end
end