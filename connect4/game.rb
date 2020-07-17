require 'yaml'
require_relative './invalid_move_error'

module Connect4
  class Game
    RED = 'red'
    BLUE = 'blue'

    attr_reader :turn

    def initialize(
      player1_board: 0,
      player2_board: 0,
      peaks: [0, 7, 14, 21, 28, 35, 42],
      turn: 0
    )
      @bitboards = [player1_board, player2_board]
      @peaks = peaks
      @turn = turn
    end

    def self.load(game_data)
      data = YAML.load(game_data)
      Game.new(**data)
    end

    def over?
      valid_moves.empty? || !winner.nil?
    end

    def status_string
      if over?
        if win?(@bitboards[0])
          "#{RED.capitalize} team wins!"
        elsif win?(@bitboards[1])
          "#{BLUE.capitalize} team wins!"
        else
          'The game was a draw!'
        end
      else
        'The game still is ongoing'
      end
    end

    def result
      if winner.nil?
        'Draw'
      else
        winner
      end
    end

    # We can safely memoize here because only 1 move is ever made at a time
    def winner
      @winner ||= begin
        if win?(@bitboards[0])
          RED
        elsif win?(@bitboards[1])
          BLUE
        else
          nil
        end
      end
    end

    def make_move(column)
      raise InvalidMoveError unless valid_moves.include?(column)

      column -= 1 # Logic uses 0 based indexing
      move = 1 << @peaks[column]
      @peaks[column] += 1
      @bitboards[@turn & 1] ^= move
      @turn += 1
    end

    def valid_moves
      (1..7).filter { |column| (TOP & (1 << @peaks[column - 1])) == 0 }
    end

    def current_turn
      turn.even? ? RED : BLUE
    end

    def serialize
      {
        player1_board: @bitboards[0],
        player2_board: @bitboards[1],
        peaks: @peaks,
        turn: turn,
      }.to_yaml
    end

    def board
      board = Array.new(6) { Array.new(7) { '*' } }

      0.upto(5) do |row|
        0.upto(7) do |col|
          value = row + 7 * col
          if ((@bitboards[0] >> value) & 1) == 1
            board[row][col] = RED
          elsif ((@bitboards[1] >> value) & 1) == 1
            board[row][col] = BLUE
          end
        end
      end
      board = board.reverse
    end

    def print_board
      puts board.map { |row| row.join(' ') }.join("\n")
    end

    private

    TOP = 0b1000000_1000000_1000000_1000000_1000000_1000000_1000000

    def win?(bitboard)
      [1, 6, 7, 8].each do |direction|
        return true if (bitboard & (bitboard >> direction) & (bitboard >> (2 * direction)) & (bitboard >> (3 * direction)) != 0)
      end

      false
    end
  end
end
