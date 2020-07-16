class MarkdownGenerator
  IMAGE_BASE_URL = 'https://raw.githubusercontent.com/JonathanGin52/JonathanGin52/master/images'
  ISSUE_BASE_URL = 'https://github.com/JonathanGin52/JonathanGin52/issues/new'

  def initialize(game:, issue_title:, octokit:, user:)
    @game = game
    @issue_title = issue_title
    @octokit = octokit
    @user = user
  end

  def generate
    current_turn = game.current_turn

    markdown = <<~HTML
        # Hey, I'm Jonathan 👋

        [![Twitter Badge](https://img.shields.io/badge/-@JonathanGin52-1ca0f1?style=flat-square&labelColor=1ca0f1&logo=twitter&logoColor=white&link=https://twitter.com/jonathangin52)](https://twitter.com/jonathangin52) [![Linkedin Badge](https://img.shields.io/badge/-JonathanGin-blue?style=flat-square&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/jonathangin/)](https://www.linkedin.com/in/jonathangin/)

        Nice to meet you! My name is Jonathan. I'm currently studying and working as a [Dev Degree](https://devdegree.ca/) intern @Shopify. I previously worked on building the [Shopify Fulfillment Network](https://www.shopify.com/fulfillment) as a fullstack developer. Nowadays, I am working on Shopify's Experimentation Platform as a data developer.
        <!-- ![visitors](https://visitor-badge.glitch.me/badge?page_id=JonathanGin52.JonathanGin52) -->

        ## Join my community Connect Four game!
        Everyone is welcome to participate! To make a move, click on the number at the top of the column you wish to drop a piece in.

        It is the **#{current_turn}** team's turn to play.
    HTML

    valid_moves = game.valid_moves
    headers = (1..7).map do |column|
      if valid_moves.include?(column)
        "[#{column}](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7C#{column}&body=Just+push+%27Submit+new+issue%27.+You+don%27t+need+to+do+anything+else.)"
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

          GAME OVER! #{game.status_string}. [Click here to start a new game!](#{ISSUE_BASE_URL}?title=connect4%7Cnew)
      HTML
    end

    markdown.concat <<~HTML

        Learn more about how this works: https://github.com/JonathanGin52/JonathanGin52/tree/master/connect4

        **Most recent moves**
        | Team | Move | Sent by |
        | ---- | ---- | ------- |
    HTML

    unless issue_title.start_with?('connect4|new')
      *, team, move = issue_title.split('|')
      markdown.concat("| #{team.capitalize} | #{move} | [@#{user}](https://github.com/#{user}) |\n")
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

  attr_reader :game, :octokit, :issue_title, :user
end
