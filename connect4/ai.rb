require_relative './game'

module Connect4
  class Ai
    def initialize(game:)
      @source_game = game
      @current_player = game.current_turn
      @best_move = -1
    end

    def best_move(depth: 8)
      minmax(@source_game.clone, depth, true, -Float::INFINITY, Float::INFINITY)
      @best_move
    end

    private

    def minmax(game, depth, maximizing_player, alpha, beta)
      return score(game, depth) if depth == 0 || game.over?

      if maximizing_player
        value = -Float::INFINITY
        moves = {}
        game.valid_moves.shuffle.each do |move|
          simulated_game = game.clone
          simulated_game.make_move(move)

          move_value = minmax(simulated_game, depth - 1, false, alpha, beta)
          moves[move] = move_value
          value = [value, move_value].max

          alpha = move_value if move_value > alpha
          break if alpha >= beta
        end
        @best_move = moves.key(moves.values.max)
        value
      else
        value = Float::INFINITY
        game.valid_moves.shuffle.each do |move|
          simulated_game = game.clone
          simulated_game.make_move(move)

          move_value = minmax(simulated_game, depth - 1, true, alpha, beta)
          value = [value, move_value].min

          beta = move_value if move_value < beta
          break if alpha >= beta
        end
        value
      end
    end

    # TODO: Revisit to come up with a better scoring heuristic
    def score(game, depth)
      winner = game.winner
      if winner.nil?
        0
      elsif winner == @current_player
        22 - depth
      else
        -(22 - depth)
      end
    end
  end
end
