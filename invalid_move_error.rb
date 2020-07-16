module Connect4
  class InvalidMoveError < StandardError
    def initialize(msg='Invalid move')
      super(msg)
    end
  end
end
