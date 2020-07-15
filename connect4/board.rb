#   6 13 20 27 34 41 48   55 62     Additional row
# +---------------------+
# | 5 12 19 26 33 40 47 | 54 61     top row
# | 4 11 18 25 32 39 46 | 53 60
# | 3 10 17 24 31 38 45 | 52 59
# | 2  9 16 23 30 37 44 | 51 58
# | 1  8 15 22 29 36 43 | 50 57
# | 0  7 14 21 28 35 42 | 49 56 63  bottom row
# +---------------------+

class Board
  TOP = 0b1000000_1000000_1000000_1000000_1000000_1000000_1000000

  attr_reader :board

  def initialize
    @bitboards = [0, 0]
    @height = [0, 7, 14, 21, 28, 35, 42]
    @history = []
    @counter = 0
  end

  def winner
    if win?(bitboards[0])
      puts 'p1 winner'
      true
    elsif win?(bitboards[1])
      puts 'p2 winner'
      true
    else
      false
    end
  end

  def make_move(column)
    move = 1 << height[column]
    height[column] += 1
    bitboards[counter & 1] ^= move
    history[counter] = column
    @counter += 1
  end

  def list_moves
    (0..6).filter { |column| (TOP & (1 << height[column])) == 0 }
  end

  def to_s
    board = Array.new(6) { Array.new(7) { '*' } }

    0.upto(5) do |row|
      0.upto(7) do |col|
        value = row + 7 * col
        if ((bitboards[0] >> value) & 1) == 1
          # P1 piece
          board[row][col] = 'X'
        elsif ((bitboards[1] >> value) & 1) == 1
          # P2 piece
          board[row][col] = '0'
        end
      end
    end
    board = board.reverse

    board.map { |row| row.join(' ') }.join("\n")
  end

  private

  def win?(bitboard)
    [1, 6, 7, 8].each do |direction|
      # shifted_bitboard = bitboard & (bitboard >> direction)
      # return true if (shifted_bitboard && (shifted_bitboard >> (2 * direction))) != 0
      return true if (bitboard & (bitboard >> direction) & (bitboard >> (2 * direction)) & (bitboard >> (3 * direction)) != 0)
    end

    false
  end

  attr_accessor :bitboards, :height, :history, :counter
end
