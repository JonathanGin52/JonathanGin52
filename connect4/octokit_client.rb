require 'octokit'

class OctokitClient
  PREVIEW_HEADERS = [
    ::Octokit::Preview::PREVIEW_TYPES[:reactions],
    ::Octokit::Preview::PREVIEW_TYPES[:integrations]
  ].freeze

  def initialize(github_token:, repository:, issue:)
    @octokit = Octokit::Client.new(access_token: github_token)
    @octokit.auto_paginate = true
    @octokit.default_media_type = ::Octokit::Preview::PREVIEW_TYPES[:integrations]
    @repository = repository
    @issue = issue
  end

  def add_reaction(reaction:)
    @octokit.create_issue_reaction(@repository, @issue, reaction, {accept: PREVIEW_HEADERS})
  end

  def add_comment(comment:)
    @octokit.add_comment(@repository, @issue, comment)
  end

  def fetch_from_repo(filepath)
    @octokit.contents(@repository, path: filepath)
  end

  def write_to_repo(filepath:, message:, sha:, content:)
    @octokit.update_contents(@repository, filepath, message, sha, content)
  end

  def error_notification(reaction:, comment:, error: nil)
    add_reaction(reaction: reaction)
    add_comment(comment: comment)
    @octokit.close_issue(@repository, @issue)
    unless error.nil?
      puts '-----------'
      puts "Exception: #{error.full_message}"
      puts '-----------'
    end
  end
end
