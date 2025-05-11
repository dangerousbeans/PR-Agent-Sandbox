require 'thread'

module AiAgentManager
  class AgentManager
    def initialize(config)
      @config = config
      @github = GithubClient.new(config.github_access_token)
      




      @codex = CodexClient.new(config.openai_api_key)
      @repo = config.github_repo
      @queue = Queue.new
      @agents = []
    end

    # Start the issue watcher and agent workers
    def start
      watcher = IssueWatcher.new(@github, @repo, @queue, @config.poll_interval)
      watcher.start
      @config.agents_count.times do |i|
        @agents << Thread.new do
          agent = Agent.new(i + 1, @github, @codex, @repo)
          loop do
            issue = @queue.pop
            agent.work(issue)
          end
        end
      end
      @agents.each(&:join)
    end
  end
end