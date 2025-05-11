require 'yaml'

module AiAgentManager
  class Config
    attr_reader :settings

    def initialize(config_file = 'config.yml')
      unless File.exist?(config_file)
        raise "Config file #{config_file} not found."
      end
      @settings = YAML.load_file(config_file)
    end

    def github_repo
      settings.dig('github', 'repo')
    end

    def github_access_token
      settings.dig('github', 'access_token') || ENV['GITHUB_TOKEN']
    end

    def openai_api_key
      settings.dig('openai', 'api_key') || ENV['OPENAI_API_KEY']
    end

    def agents_count
      settings.dig('agents', 'count') || 1
    end

    def poll_interval
      settings.dig('issue_watcher', 'poll_interval') || 60
    end
  end
end