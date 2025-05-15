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
            # Skip issues already enqueued
            next if @known_issues[issue.number]
            # Only pick up if the last comment isn't an agent claim (by message) to avoid re-taking claimed issues
            comments = @github_client.list_comments(@repo, issue.number)
            last_comment = comments.last
            # Enqueue if no comments or last comment does not start with our agent prefix
            if last_comment.nil? || !last_comment.body.start_with?("Agent ")
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