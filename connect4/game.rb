require_relative './board'

class Game
  def initialize
    @board = Board.new
    game_loop
  end

  def game_loop
    until @board.winner
      puts 'Make move'
      puts "Options: #{@board.list_moves.join(' ')}"
      col = gets.chomp.to_i

      @board.make_move(col)
      puts '0 1 2 3 4 5 6'
      puts @board
    end
  end
end

Game.new
