module Connect4
  class MalformedCommandError < StandardError
    def initialize(msg='Malformed command')
      super(msg)
    end
  end
end
