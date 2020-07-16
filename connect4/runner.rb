require_relative './octokit_client'
require_relative './synchronization_error'
require_relative './invalid_move_error'
require_relative './game'

module Connect4
  class MalformedCommandError < StandardError;end
  class Runner
    IMAGE_BASE_URL = 'https://raw.githubusercontent.com/JonathanGin52/JonathanGin52/master/images'
    GAME_DATA_PATH = 'connect4/connect4.yml'
    MARKDOWN_PATH = 'connect4.md'

    def initialize(github_token:, issue_number:, issue_title:, repository:, user:)
      @github_token = github_token
      @repository = repository
      @issue_number = issue_number
      @issue_title = issue_title
      @user = user
    end

    def run
      split_input = @issue_title.split('|')
      command = split_input[1]

      octokit.add_reaction(reaction: 'eyes')
      octokit.close_issue

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
      game.make_move(move)
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
      # File.write(GAME_DATA_PATH, game.serialize)
      # File.write(MARKDOWN_PATH, to_markdown)
    end

    def to_markdown
      markdown = <<~HTML
        # Hey, I'm Jonathan 👋

        [![Twitter Badge](https://img.shields.io/badge/-@JonathanGin52-1ca0f1?style=flat-square&labelColor=1ca0f1&logo=twitter&logoColor=white&link=https://twitter.com/jonathangin52)](https://twitter.com/jonathangin52) [![Linkedin Badge](https://img.shields.io/badge/-JonathanGin-blue?style=flat-square&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/jonathangin/)](https://www.linkedin.com/in/jonathangin/)

        Nice to meet you! My name is Jonathan. I'm currently studying and working as a [Dev Degree](https://devdegree.ca/) intern @Shopify. I previously worked on building the [Shopify Fulfillment Network](https://www.shopify.com/fulfillment) as a fullstack developer. Nowadays, I am working on Shopify's Experimentation Platform as a data developer.
        <!-- ![visitors](https://visitor-badge.glitch.me/badge?page_id=JonathanGin52.JonathanGin52) -->

        ## Join my community Connect Four game!
        Everyone is welcome to participate! To make a move, click on the number at the top of the column you wish to play.

        It is the **#{game.current_turn}** team's turn to play.
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

      if game.over?
        markdown.concat <<~HTML
          GAME OVER! #{game.status_string}. [Click here to start a new game!](#{issues_base_url}?title=connect4%7Cnew)
        HTML
      end

      markdown.concat <<~HTML

        **Last few moves**
        | Team | Move | Sent by |
        | ---- | ---- | ------- |
      HTML

      unless @issue_title.start_with?('connect4|new')
        *, team, move = @issue_title.split('|')
        markdown.concat("| #{team.capitalize} | #{move} | [@#{@user}](https://github.com/#{@user}) |\n")
      end

      if octokit.issues.nil?
        markdown.concat "| Oh no... | ¯\\_(ツ)_/¯ | History temporarily unavailable. |\n"
      else
        octokit.issues.first(5).each do |issue|
          break if issue.title.start_with?('connect4|new')

          if issue.title.start_with?('connect4|drop|')
            *, team, move = issue.title.split('|')
            user = issue.user.login
            markdown.concat("| #{team.capitalize} | #{move} | [@#{user}](https://github.com/#{user}) |\n")
          end
        end
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
      @octokit ||= OctokitClient.new(github_token: @github_token, repository: @repository, issue_number: @issue_number)
    end
  end
end
