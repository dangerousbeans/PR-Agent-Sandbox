 require 'minitest/autorun'
 require 'tmpdir'
 require 'fileutils'
 require 'ostruct'

# Prevent automatic removal of temp dirs and track them for inspection
$TMPDIRS = []
class Dir
  class << self
    def mktmpdir(prefix=nil, tmpdir=nil)
      base = tmpdir || Dir.tmpdir
      prefix_str = prefix || ''
      path = File.join(base, "#{prefix_str}#{Time.now.to_i}#{rand(0x10000)}")
      Dir.mkdir(path)
      $TMPDIRS << path
      if block_given?
        yield path
      else
        path
      end
    end
  end
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'ai_agent_manager/agent'

class DummyGithubClient
  attr_accessor :access_token
  attr_reader :comments, :branches, :pull_requests

  def initialize
    @comments = []
    @branches = []
    @pull_requests = []
  end

  def comment_on_issue(repo, issue_number, body)
    @comments << [repo, issue_number, body]
  end

  def create_branch(repo, branch_name, base_branch)
    @branches << [repo, branch_name, base_branch]
  end

  def create_pull_request(repo, title, head, base, body)
    @pull_requests << [repo, title, head, base, body]
    OpenStruct.new(html_url: 'http://example.com/pr')
  end

  # Other methods unused in this test
end

class DummyCodexClient
  attr_reader :calls

  def initialize
    @calls = []
  end

  def generate_patch(instructions, dir, branch_name)
    @calls << [instructions, dir, branch_name]
    File.open(File.join(dir, 'file.txt'), 'a') { |f| f.write("patch\n") }
  end
end

class AgentWorkTest < Minitest::Test
  def setup
    @github = DummyGithubClient.new
    @github.access_token = ''
    @codex = DummyCodexClient.new
    @agent = AiAgentManager::Agent.new(1, @github, @codex, 'dummy_repo')

    # Override clone_repo to initialize a local git repo for testing
    def @agent.clone_repo
      system('git', 'init')
      File.write('file.txt', "hello\n")
      system('git', 'add', 'file.txt')
      system('git', 'commit', '-m', 'initial')
    end

    # Stub out git push to avoid remote errors
    def @agent.system(*args)
      cmd = args.join(' ')
      if cmd.start_with?('git push')
        true
      else
        super(*args)
      end
    end

    @issue = OpenStruct.new(
      number: 42,
      title: 'Update file',
      body: 'Please update file.txt'
    )
  end

  def teardown
    # Clean up any directories created
    $TMPDIRS.each { |dir| FileUtils.rm_rf(dir) rescue nil }
  end

  def test_work_flow_creates_branch_commits_and_pr
    @agent.work(@issue)

    # Verify initial comment
    assert_equal [['dummy_repo', 42, 'Agent 1 is on it!']], @github.comments

    # Verify codex was called with correct arguments
    assert_equal 1, @codex.calls.size
    instructions, dir, branch = @codex.calls.first
    assert_equal "#{@issue.title} #{@issue.body}", instructions
    assert_equal "agent-1-issue-#{@issue.number}", branch

    # Inspect the temp git repo
    temp_dir = $TMPDIRS.last
    # Verify branch was checked out locally
    current_branch = `git -C "#{temp_dir}" rev-parse --abbrev-ref HEAD`.strip
    assert_equal "agent-1-issue-#{@issue.number}", current_branch

    # Verify that patch was applied (file ends with 'patch')
    content = File.read(File.join(temp_dir, 'file.txt'))
    assert_match /patch$/, content

    # Verify commit history has two commits: initial and patch
    log = `git -C "#{temp_dir}" log --oneline`.lines
    assert_equal 2, log.size
    assert_match /Apply changes for issue/, log.first

    # Verify GitHub branch creation and PR creation calls
    assert_equal [['dummy_repo', "agent-1-issue-42", 'main']], @github.branches
    assert_equal [['dummy_repo', "Resolve issue #42", 'agent-1-issue-42', 'main', 'Closes #42']], @github.pull_requests
  end
end