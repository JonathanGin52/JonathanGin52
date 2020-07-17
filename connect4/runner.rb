require_relative './game'
require_relative './ai'
require_relative './octokit_client'
require_relative './markdown_generator'
require_relative './synchronization_error'
require_relative './malformed_command_error'
require_relative './invalid_move_error'

module Connect4
  class Runner
    IMAGE_BASE_URL = 'https://raw.githubusercontent.com/JonathanGin52/JonathanGin52/master/images'
    GAME_DATA_PATH = 'connect4/connect4.yml'
    MARKDOWN_PATH = 'README.md'

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

      acknowledge_issue

      if command == 'drop'
        handle_move(player: split_input[2], move: split_input[3])
      elsif command == 'new'
        handle_new_game
      else
        raise MalformedCommandError, "unrecognized command"
      end

      # Write game state
      write
    rescue ArgumentError => e
      comment = "There seems to be an error in your input\nError: #{e.message}"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    rescue MalformedCommandError => e
      comment = "Your command could not be parsed. Make sure you don't edit the issue title."
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    end

    private

    def handle_move(player:, move:)
      raise SynchronizationError unless game.current_turn == player

      move = Connect4::Ai.new(game: game).best_move if move == 'ai'
      @ai_move = move
      game.make_move(Integer(move))
    rescue SynchronizationError => e
      comment = "The board has changed since this issue was opened. Someone must've snuck a move in right before you. Please refresh and try again."
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    rescue InvalidMoveError => e
      comment = "The move you have selected is invalid. Please double check the board and try again."
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    end

    def handle_new_game
      if game.over? || @user.downcase == 'jonathangin52'
        @game = Game.new
      else
        comment = "There is currently a game still in progress!"
        octokit.error_notification(reaction: 'confused', comment: comment)
      end
    end

    def write
      *, command, team, move = @issue_title.split('|')
      handle = if move == 'ai'
        move = @ai_move
        'Connect4Bot'
      else
        "@#{@user}"
      end

      message = if command == 'drop'
        "#{handle} dropped a #{team} disk in column #{move}"
      else
        "@#{@user} started a new game!"
      end
      if @development
        File.write(GAME_DATA_PATH, game.serialize)
        File.write(MARKDOWN_PATH, to_markdown)
        puts message
      else
        octokit.write_to_repo(
          filepath: GAME_DATA_PATH,
          message: message,
          sha: raw_game_data.sha,
          content: game.serialize
        )
        octokit.write_to_repo(
          filepath: MARKDOWN_PATH,
          message: message,
          sha: raw_markdown_data.sha,
          content: to_markdown,
        )
        octokit.add_reaction(reaction: 'rocket')
      end
    end

    def to_markdown
      MarkdownGenerator.new(
        game: game,
        issue_title: @issue_title,
        octokit: octokit,
      ).generate(ai_move: @ai_move)
    end

    def acknowledge_issue
      octokit.add_label(label: 'connect4')
      octokit.add_reaction(reaction: 'eyes')
      octokit.close_issue
    end

    def game
      @game ||= Game.load(Base64.decode64(raw_game_data.content))
    end

    def raw_game_data
      @raw_game_data ||= octokit.fetch_from_repo(GAME_DATA_PATH)
    end

    def raw_markdown_data
      @raw_markdown_data ||= octokit.fetch_from_repo(MARKDOWN_PATH)
    end

    def octokit
      @octokit ||= OctokitClient.new(github_token: @github_token, repository: @repository, issue_number: @issue_number)
    end
  end
end
