require_relative './game'
require_relative './ai'
require_relative './octokit_client'
require_relative './markdown_generator'
require_relative './synchronization_error'
require_relative './malformed_command_error'
require_relative './invalid_move_error'

require 'yaml'

module Connect4
  class Runner
    GAME_DATA_PATH = 'connect4/connect4.yml'
    METADATA_FILE_PATH = 'connect4/metadata.yml'
    README_PATH = 'README.md'

    def initialize(
      github_token:,
      issue_number:,
      issue_title:,
      repository:,
      user:,
      development: false
    )
      @github_token = github_token
      @repository = repository
      @issue_number = issue_number
      @issue_title = issue_title
      @user = user
      @development = development
    end

    def run
      split_input = @issue_title.split('|')
      command = split_input[1]
      team = split_input[2]
      move = split_input[3]

      acknowledge_issue

      if command == 'drop'
        handle_move(team: team, move: move)
      elsif command == 'new'
        handle_new_game
      else
        raise MalformedCommandError, "unrecognized command"
      end

      write_game_state(command: command, team: team, move: move)
    rescue ArgumentError => e
      comment = ":warning: There seems to be an error in your input.\nError: #{e.message}"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    rescue MalformedCommandError => e
      comment = ":warning: Your command could not be parsed. Make sure you don't edit the issue title!"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    rescue StandardError => e
      comment = ":warning: Hmm, something seems to have gone wrong.\nError: #{e.message}\ncc: @JonathanGin52"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    end

    private

    def handle_move(team:, move:)
      raise SynchronizationError unless game.current_turn == team

      if move == 'ai'
        move = Ai.new(game: game).best_move
        @ai_move = move
        octokit.add_comment(comment: ":robot: Connect4Bot dropped a disk in column: **#{move}**")
      else
        issue = octokit.issues[1]
        if issue.user.login == @user && !issue.title.end_with?('ai', 'new')
          comment = "Hey, no cheating :eyes:! You just played the most recent move. Ask a friend to make the next move, or alternatively, ask Connect4Bot to " \
          "[make a move](#{MarkdownGenerator::ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{team}%7Cai&#{MarkdownGenerator::ISSUE_BODY})"
          octokit.error_notification(reaction: 'confused', comment: comment)
        end
      end
      game.make_move(Integer(move))
      metadata[:all_players][@user] += 1

      handle_game_over if game.over?
    rescue SynchronizationError => e
      comment = "Uh oh, there was a synchronization error! You had requested to drop a disk for the **#{team}** team, however it was the **#{game.current_turn}** team's turn to play. This was most likely caused by someone sneaking a move in right before you. Please refresh the page and try again."
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    rescue InvalidMoveError => e
      comment = "**#{move}** is an invalid move. Please double check the board and try again."
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    end

    def handle_new_game
      if game.over? || @user == 'JonathanGin52'
        @game = Game.new
      else
        comment = "There is currently a game still in progress!"
        octokit.error_notification(reaction: 'confused', comment: comment)
      end
    end

    def handle_game_over
      metadata[:completed_games] += 1
      unless game.winner.nil?
        winning_player = @ai_move.nil? ? @user : 'Connect4Bot'
        metadata[:game_winning_players][winning_player] += 1
      end

      red_team = Hash.new(0)
      blue_team = Hash.new(0)

      octokit.issues.each do |issue|
        break if issue.title.start_with?('connect4|new')

        *, command, team, move = issue.title.split('|')
        if command == 'drop'
          user = "@#{issue.user.login}"
          user.concat(' :robot:') if move == 'ai'
          if team == Game::RED
            red_team[user] += 1
          else
            blue_team[user] += 1
          end
        end
      end

      game_over_message = MarkdownGenerator.new(game: game).game_over_message(red_team: red_team, blue_team: blue_team)
      if @development
        File.write('game_over.md', game_over_message)
      else
        octokit.add_comment(comment: game_over_message)
      end
    end

    def write_game_state(command:, team:, move:)
      handle = if move == 'ai'
        move = @ai_move
        ':robot: Connect4Bot'
      else
        "@#{@user}"
      end

      message = if command == 'drop'
        "#{handle} dropped a #{team} disk in column #{move}"
      else
        "@#{@user} started a new game!"
      end

      File.write(GAME_DATA_PATH, game.serialize)
      File.write(README_PATH, generate_readme)

      if @development
        File.write('connect4/local.yml', game.serialize)
        File.write('connect4/local_metadata.yml', metadata.to_yaml)
        puts message
      else
        File.write(METADATA_FILE_PATH, metadata.to_yaml)
        `git add #{GAME_DATA_PATH} #{README_PATH} #{METADATA_FILE_PATH}`
        `git config --global user.email "github-action-bot@example.com"`
        `git config --global user.name "GitHub Action Bot"`
        if system("git commit -m '#{message}'") && system('git push')
          octokit.add_reaction(reaction: 'rocket')
        else
          comment = "Oh no! There was a network issue. This is a transient error. Please try again!"
          octokit.error_notification(reaction: 'confused', comment: comment)
        end
      end
    end

    def generate_readme
      recent_moves = []
      octokit.issues.each do |issue|
        break if recent_moves.length == 3 || issue.title.start_with?('connect4|new')

        if issue.title.start_with?('connect4|drop|')
          *, team, move = issue.title.split('|')
          login = issue.user.login
          github_user = "[@#{login}](https://github.com/#{login})"
          user = if move == 'ai'
            comment = octokit.fetch_comments(issue_number: issue.number).find { |comment| comment.user.login == 'github-actions[bot]' }
            move = comment.body[/\*\*(\d)\*\*/, -1]
            "Connect4Bot on behalf of #{github_user}"
          else
            github_user
          end
          recent_moves << [team.capitalize, move, user]
        end
      end
      MarkdownGenerator.new(game: game).readme(metadata: metadata, recent_moves: recent_moves)
    end

    def acknowledge_issue
      octokit.add_label(label: 'connect4')
      octokit.add_reaction(reaction: 'eyes')
      octokit.close_issue
    end

    def metadata
      @metadata ||= begin
        metadata = YAML.load_file(METADATA_FILE_PATH)
        metadata[:all_players].default = 0
        metadata[:game_winning_players].default = 0
        metadata
      end
    end

    def game
      @game ||= begin
        if @development
          Game.new(YAML.load_file('connect4/local.yml'))
        else
          Game.load(Base64.decode64(raw_game_data.content))
        end
      end
    end

    def raw_game_data
      @raw_game_data ||= octokit.fetch_from_repo(GAME_DATA_PATH)
    end

    def raw_markdown_data
      @raw_markdown_data ||= octokit.fetch_from_repo(README_PATH)
    end

    def octokit
      @octokit ||= OctokitClient.new(github_token: @github_token, repository: @repository, issue_number: @issue_number)
    end
  end
end
