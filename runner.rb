require_relative './octokit_client'
require_relative './synchronization_error'
require_relative './invalid_move_error'
require_relative './game'

module Connect4
  class MalformedCommandError < StandardError;end
  class Runner
    IMAGE_BASE_URL = 'https://raw.githubusercontent.com/JonathanGin52/JonathanGin52/connect-4/images'
    GAME_DATA_PATH = 'connect4/connect4.yml'
    MARKDOWN_PATH = 'connect4.md'

    def initialize(github_token:, issue:, repository: 'JonathanGin52/JonathanGin52')
      @github_token = github_token
      @repository = repository
      @issue = issue
    end

    def parse_input(github_issue_title)
      split_input = github_issue_title.split('|')
      command = split_input[1]

      if command == 'drop'
        handle_move(player: split_input[2], move: Integer(split_input[3]))
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
      comment = "Your command could not be parsed"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    end

    def handle_move(player:, move:)
      raise SynchronizationError unless game.current_turn == player
      game.make_move(move.to_i)
    rescue SynchronizationError => e
      comment = "The board has changed since this issue was opened. Someone must've snuck a move in right before you"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    rescue InvalidMoveError => e
      comment = "The move you have selected is invalid. Please double check the board and try again"
      octokit.error_notification(reaction: 'confused', comment: comment, error: e)
    end

    def handle_new_game
      if game.over?
        @game = Game.new
      else
        comment = "There is current a game still in progress!"
        octokit.error_notification(reaction: 'confused', comment: comment)
      end
    end

    def write
      octokit.write_to_repo(
        filepath: GAME_DATA_PATH,
        message: 'Update game state',
        sha: raw_game_data.sha,
        content: game.serialize
      )
      octokit.write_to_repo(
        filepath: MARKDOWN_PATH,
        message: 'Update game board',
        sha: raw_markdown_data.sha,
        content: to_markdown,
      )
      # File.write('./connect4/connect4.yml', game.serialize)
      # File.write('temp.md', to_markdown)
    end

    def to_markdown
      markdown = <<~HTML
        ## Community Connect-4
      HTML

      valid_moves = game.valid_moves
      turn = game.current_turn
      issue_base_url = 'https://github.com/JonathanGin52/JonathanGin52/issues/new'
      headers = (1..7).map do |column|
        if valid_moves.include?(column)
          "[#{column}](#{issue_base_url}?title=connect4%7Cdrop%7C#{turn}%7C#{column}&body=Just+push+%27Submit+new+issue%27.+You+don%27t+need+to+do+anything+else.)"
        else
          column.to_s
        end
      end

      markdown.concat("|#{headers.join('|')}|\n")
      markdown.concat("| - | - | - | - | - | - | - |\n")

      red = "![](#{IMAGE_BASE_URL}/red.png)"
      blue = "![](#{IMAGE_BASE_URL}/blue.png)"
      blank = "![](#{IMAGE_BASE_URL}/blank.png)"

      game.board.each do |row|
        format = row.map do |cell|
          if cell == 'X'
            red
          elsif cell == 'O'
            blue
          else
            blank
          end
        end
        markdown.concat("|#{format.join('|')}|\n")
      end

      markdown
    end

    private

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
      @octokit ||= OctokitClient.new(github_token: @github_token, repository: @repository, issue: @issue)
    end
  end
end
