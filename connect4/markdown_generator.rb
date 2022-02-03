require_relative './game'

class MarkdownGenerator
  IMAGE_BASE_URL = 'https://raw.githubusercontent.com/JonathanGin52/JonathanGin52/main/images'
  ISSUE_BASE_URL = 'https://github.com/JonathanGin52/JonathanGin52/issues/new'
  ISSUE_BODY = 'body=Just+push+%27Submit+new+issue%27+without+editing+the+title.+The+README+will+be+updated+after+approximately+30+seconds.'

  RED_IMAGE = "![](#{IMAGE_BASE_URL}/red.png)"
  BLUE_IMAGE = "![](#{IMAGE_BASE_URL}/blue.png)"
  BLANK_IMAGE = "![](#{IMAGE_BASE_URL}/blank.png)"

  def initialize(game:)
    @game = game
  end

  def readme(metadata:, recent_moves:)
    current_turn = game.current_turn

    total_moves_played = metadata[:all_players].values.sum
    completed_games = metadata[:completed_games]
    game_winning_players = metadata[:game_winning_players].sort_by { |_, wins| -wins }

    markdown = <<~HTML
        # Hey, I'm Jonathan 👋

        [![Twitter Badge](https://img.shields.io/badge/-@JonathanGin52-1ca0f1?style=flat-square&labelColor=1ca0f1&logo=twitter&logoColor=white&link=https://twitter.com/jonathangin52)](https://twitter.com/jonathangin52) [![Linkedin Badge](https://img.shields.io/badge/-JonathanGin-blue?style=flat-square&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/jonathangin/)](https://www.linkedin.com/in/jonathangin/)

        Nice to meet you! I'm currently studying and working as a [Dev Degree](https://devdegree.ca/) intern [@Shopify](https://www.shopify.com/).
        I've previously worked on building the [Shopify Fulfillment Network](https://www.shopify.com/fulfillment) as a fullstack developer, Shopify's Experimentation Platform as a data developer, and Shopify Checkout as a backend developer.
        Nowadays, I'm working on Shopify Caching Platform as a production engineer.

        ## :game_die: Join my community Connect Four game!
        ![](https://img.shields.io/badge/Moves%20played-#{total_moves_played}-blue)
        ![](https://img.shields.io/badge/Completed%20games-#{completed_games}-brightgreen)
        ![](https://img.shields.io/badge/Total%20players-#{metadata[:all_players].size}-orange)

        Everyone is welcome to participate! To make a move, click on the **column number** you wish to drop your disk in.

    HTML

    game_status = if game.over?
      "#{game.status_string} [Click here to start a new game!](#{ISSUE_BASE_URL}?title=connect4%7Cnew&#{ISSUE_BODY})"
    else
      "It is the **#{current_turn}** team's turn to play."
    end

    markdown.concat("#{game_status}\n\n")

    markdown.concat(generate_game_board)

    unless game.over?
      markdown.concat("\nTired of waiting? [Request a move](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7Cai&#{ISSUE_BODY}) from Connect4Bot :robot: \n")
    end

    markdown.concat <<~HTML

        Interested in how everything works? [Click here](https://github.com/JonathanGin52/JonathanGin52/tree/main/connect4) to read up on what's happening behind the scenes.

        **:alarm_clock: Most recent moves**
        | Team | Move | Made by |
        | ---- | ---- | ------- |
    HTML

    recent_moves.each { |(team, move, user)| markdown.concat("| #{team} | #{move} | #{user} |\n") }

    markdown.concat <<~HTML

        **:trophy: Leaderboard: Top 10 players with the most game winning moves :1st_place_medal:**
        | Player | Wins |
        | ------ | -----|
    HTML

    game_winning_players.first(10).each do |player, wins|
      user = if player == 'Connect4Bot'
        'Connect4Bot :robot:'
      else
        "[@#{player}](https://github.com/#{player})"
      end
      markdown.concat("| #{user} | #{wins} |\n")
    end

    markdown
  end

  def game_over_message(red_team:, blue_team:)
    winner = game.winner
    victory_text = if winner.nil?
      'The game ended in a draw, how anticlimactic!'
    else
      "The **#{winner}** team has emerged victorious! :trophy:"
    end

    <<~HTML
      # :tada: The game has ended :confetti_ball:
      #{victory_text}

      [Click here to start a new game!](#{ISSUE_BASE_URL}?title=connect4%7Cnew&#{ISSUE_BODY})

      ### :star: Game board
      #{generate_game_board}

      ## Thank you to everybody who participated!

      ### Red team roster
      #{generate_player_moves_table(red_team)}

      ### Blue team roster
      #{generate_player_moves_table(blue_team)}
    HTML
  end

  private

  attr_reader :game

  def generate_game_board
    valid_moves = game.valid_moves
    current_turn = game.current_turn
    headers = if valid_moves.empty?
      '1|2|3|4|5|6|7'
    else
      (1..7).map do |column|
        if valid_moves.include?(column)
          "[#{column}](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7C#{column}&#{ISSUE_BODY})"
        else
          column.to_s
        end
      end.join('|')
    end

    game_board = "|#{headers}|\n| - | - | - | - | - | - | - |\n"

    5.downto(0) do |row|
      format = (0...7).map do |col|
        offset = row + 7 * col
        if ((game.bitboards[0] >> offset) & 1) == 1
          RED_IMAGE
        elsif ((game.bitboards[1] >> offset) & 1) == 1
          BLUE_IMAGE
        else
          BLANK_IMAGE
        end
      end
      game_board.concat("|#{format.join('|')}|\n")
    end
    game_board
  end

  def generate_player_moves_table(player_moves)
    table = "| Player | Moves made |\n| - | - |\n"
    player_moves.sort_by { |_, move_count| -move_count }.reduce(table) do |tbl, (player, move_count)|
      tbl.concat("| #{player} | #{move_count} |\n")
    end
  end
end
