require_relative './connect4/runner'

runner = Connect4::Runner.new(github_token: '7bd5c9812cdc2af6a3c24be757d19e346be7d2f4', issue: 3)

runner.parse_input('connect4|drop|blue|6')
