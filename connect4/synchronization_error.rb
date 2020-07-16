module Connect4
  class SynchronizationError < StandardError
    def initialize(msg='Synchronization error')
      super(msg)
    end
  end
end
