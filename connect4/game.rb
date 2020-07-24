require 'yaml'
require_relative './invalid_move_error'

module Connect4
  class Game
    RED = 'red'
    BLUE = 'blue'

    attr_reader :turn, :bitboards

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
          "Game over, the #{RED} team has won!"
        elsif win?(@bitboards[1])
          "Game over, the #{BLUE} team has won!"
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

    def winner
      if win?(@bitboards[0])
        RED
      elsif win?(@bitboards[1])
        BLUE
      else
        nil
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
      return [] unless winner.nil?
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

    def to_s
      board = "  1 2 3 4 5 6 7\n+---------------+\n"

      5.downto(0) do |row|
        line = (0...7).map do |col|
          value = row + 7 * col
          if ((@bitboards[0] >> value) & 1) == 1
            'X'
          elsif ((@bitboards[1] >> value) & 1) == 1
            'O'
          else
            '*'
          end
        end
        board.concat("| #{line.join(' ')} |\n")
      end
      board.concat("+---------------+\n")
    end

    def clone
      Game.new(
        player1_board: @bitboards[0],
        player2_board: @bitboards[1],
        peaks: @peaks.dup,
        turn: @turn
      )
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
