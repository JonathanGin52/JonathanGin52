require_relative './game'

class MarkdownGenerator
  IMAGE_BASE_URL = 'https://raw.githubusercontent.com/JonathanGin52/JonathanGin52/master/images'
  ISSUE_BASE_URL = 'https://github.com/JonathanGin52/JonathanGin52/issues/new'

  RED_IMAGE = "![](#{IMAGE_BASE_URL}/red.png)"
  BLUE_IMAGE = "![](#{IMAGE_BASE_URL}/blue.png)"
  BLANK_IMAGE = "![](#{IMAGE_BASE_URL}/blank.png)"

  def initialize(game:, octokit:)
    @game = game
    @octokit = octokit
  end

  def readme
    current_turn = game.current_turn

    game_winning_move_flag = false
    game_winning_players = Hash.new(0)
    players = Hash.new(0)
    total_moves_played = 0
    completed_games = 0
    octokit.issues.each do |issue|
      players[issue.user.login] += 1
      if issue.title == 'connect4|new'
        game_winning_move_flag = true
        completed_games += 1
      else
        total_moves_played += 1
        if game_winning_move_flag
          game_winning_move_flag = false
          if issue.title.end_with?('ai')
            game_winning_players['Connect4Bot'] += 1
          else
            game_winning_players[issue.user.login] += 1
          end
        end
      end
    end

    game_winning_players = game_winning_players.sort_by { |_, wins| -wins }

    markdown = <<~HTML
        # Hey, I'm Jonathan 👋

        [![Twitter Badge](https://img.shields.io/badge/-@JonathanGin52-1ca0f1?style=flat-square&labelColor=1ca0f1&logo=twitter&logoColor=white&link=https://twitter.com/jonathangin52)](https://twitter.com/jonathangin52) [![Linkedin Badge](https://img.shields.io/badge/-JonathanGin-blue?style=flat-square&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/jonathangin/)](https://www.linkedin.com/in/jonathangin/)

        Nice to meet you! My name is Jonathan. I'm currently studying and working as a [Dev Degree](https://devdegree.ca/) intern @Shopify. I previously worked on building the [Shopify Fulfillment Network](https://www.shopify.com/fulfillment) as a fullstack developer. Nowadays, I am working on Shopify's Experimentation Platform as a data developer.

        ## :game_die: Join my community Connect Four game!
        ![](https://img.shields.io/badge/Moves%20played-#{total_moves_played}-blue)
        ![](https://img.shields.io/badge/Completed%20games-#{completed_games}-brightgreen)
        ![](https://img.shields.io/badge/Total%20players-#{players.size}-orange)

        Everyone is welcome to participate! To make a move, click on the **column number** you wish to drop your disk in.

    HTML

    game_status = if game.over?
      "#{game.status_string} [Click here to start a new game!](#{ISSUE_BASE_URL}?title=connect4%7Cnew)"
    else
      "It is the **#{current_turn}** team's turn to play."
    end

    markdown.concat("#{game_status}\n\n")

    markdown.concat(generate_game_board)

    unless game.over?
      markdown.concat("\nTired of waiting? [Request a move](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7Cai&body=Just+push+%27Submit+new+issue%27.+You+don%27t+need+to+do+anything+else.) from Connect4Bot :robot: \n")
    end

    markdown.concat <<~HTML

        Interested in how everything works? [Click here](https://github.com/JonathanGin52/JonathanGin52/tree/master/connect4) to read up on what's happening behind the scenes.

        **:alarm_clock: Most recent moves**
        | Team | Move | Made by |
        | ---- | ---- | ------- |
    HTML

    count = 0
    octokit.issues.each do |issue|
      break if issue.title.start_with?('connect4|new')

      if issue.title.start_with?('connect4|drop|')
        count += 1
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
        markdown.concat("| #{team.capitalize} | #{move} | #{user} |\n")
        break if count >= 3
      end
    end

    winning_moves_leaderboard = game_winning_players.map do |player, wins|
      user = if player == 'Connect4Bot'
        'Connect4Bot :robot:'
      else
        "[@#{player}](https://github.com/#{player})"
      end
      "| #{user} | #{wins} |"
    end.join("\n")

    markdown.concat <<~HTML

        **:trophy: Leaderboard: Most game winning moves :star:**
        | Player | Wins |
        | ------ | -----|
        #{winning_moves_leaderboard}
    HTML
  end

  def game_over_message(red_team:, blue_team:)
    winner = game.winner
    victory_text = if winner.nil?
      'The game ended in a draw, how anticlimactic!'
    else
      "The **#{game.winner}** team has emerged victorious! :trophy:"
    end

    <<~HTML
      # :tada: The game has ended :confetti_ball:
      #{victory_text}

      [Click here to start a new game!](#{ISSUE_BASE_URL}?title=connect4%7Cnew)

      ### :star: Game board
      #{generate_game_board}

      ### Red team roster
      #{generate_player_moves_table(red_team)}

      ### Blue team roster
      #{generate_player_moves_table(blue_team)}
    HTML
  end

  private

  attr_reader :game, :octokit

  def generate_game_board
    valid_moves = game.valid_moves
    current_turn = game.current_turn
    headers = if valid_moves.empty?
      '1|2|3|4|5|6|7'
    else
      (1..7).map do |column|
        if valid_moves.include?(column)
          "[#{column}](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7C#{column}&body=Just+push+%27Submit+new+issue%27.+You+don%27t+need+to+do+anything+else.)"
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
