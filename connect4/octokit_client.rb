require 'octokit'

class OctokitClient
  def initialize(github_token:, repository:, issue_number:)
    @octokit = Octokit::Client.new(access_token: github_token)
    @octokit.auto_paginate = true
    @repository = repository
    @issue_number = issue_number
  end

  def add_reaction(reaction:)
    @octokit.create_issue_reaction(@repository, @issue_number, reaction)
  end

  def add_comment(comment:)
    @octokit.add_comment(@repository, @issue_number, comment)
  end

  def add_label(label:)
    @octokit.add_labels_to_an_issue(@repository, @issue_number, [label])
  end

  def close_issue
    @octokit.close_issue(@repository, @issue_number)
  end

  def fetch_from_repo(filepath)
    @octokit.contents(@repository, path: filepath)
  end

  def fetch_comments(issue_number: @issue_number)
    @octokit.issue_comments(@repository, issue_number)
  end

  def write_to_repo(filepath:, message:, sha:, content:)
    @octokit.update_contents(@repository, filepath, message, sha, content)
  end

  def issues(labels: 'connect4')
    @issues ||= @octokit.list_issues(
      @repository,
      state: 'closed',
      labels: labels,
    )&.select { |issue| issue.reactions.confused.zero? }
  end

  def error_notification(reaction:, comment:, error: nil)
    add_reaction(reaction: reaction)
    add_comment(comment: comment)
    puts comment
    unless error.nil?
      puts '-----------'
      puts "Exception: #{error.full_message}"
      puts '-----------'
    end
    exit(0)
  end
end
