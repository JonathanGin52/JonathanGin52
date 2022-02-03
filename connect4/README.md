# GitHub asynchronous Connect Four
Hey there, if you're here, you're probably interested in how everything works!

## Table of Contents
1. [GitHub automation](#github-automation)
2. [Connect Four](#board-representation)
    1. [Board representation](#board-representation)
    2. [Connect4 AI](#connect4-ai)
3. [Contributing](#contributing)
4. [Acknowledgments](#acknowledgements)

## GitHub automation
Whenever an issue with the prefix `connect4` is opened, a [GitHub Actions](https://github.com/features/actions) workflow is automatically triggered. The title of the issue and other metadata is passed to a Ruby script, which then takes the appropriate action based on the content of the issue.

## Connect Four


### Board representation
This implementation of Connect Four uses two bitboards. A [bitboard](https://en.wikipedia.org/wiki/Bitboard) is a specialized data structure that is commonly used for board game representation.
This representation was chosen because it makes serializing the game state practically trivial.
Each bitboard represents the board from one player's point of view, and is stored as an integer (Ruby is not typed, but in other languages, this would be a 64-bit integer).

The mapping between each bit and the board is shown is as following:

```
  6 13 20 27 34 41 48   55 62     extra row
+---------------------+
| 5 12 19 26 33 40 47 | 54 61     top row
| 4 11 18 25 32 39 46 | 53 60
| 3 10 17 24 31 38 45 | 52 59
| 2  9 16 23 30 37 44 | 51 58
| 1  8 15 22 29 36 43 | 50 57
| 0  7 14 21 28 35 42 | 49 56 63  bottom row
+---------------------+
```

The bits in the additional row at the top (6, 13, 20, etc) are not used to represent any discs, but will be of use when bitshifting later on.

```
* * * * * * *      0 0 0 0 0 0 0      0 0 0 0 0 0 0
* * * * * * *      0 0 0 0 0 0 0      0 0 0 0 0 0 0
* * * * * * *      0 0 0 0 0 0 0      0 0 0 0 0 0 0
* * O * * * *      0 0 0 0 0 0 0      0 0 1 0 0 0 0
* * X O * * *      0 0 1 0 0 0 0      0 0 0 1 0 0 0   
O X X X O * *      0 1 1 1 0 0 0      1 0 0 0 1 0 0    
-------------      -------------      -------------     
0 1 2 3 4 5 6      X's Bitboard       O's Bitboard 
```

This translates into to the following numerical representation.

```
  2146432  =  0000000 0000000 0000000 0000001 0000011 0000001 0000000 // X's bitboard
272695297  =  0000000 0000000 0000001 0000010 0000100 0000000 0000001 // O's bitboard
               col 6   col 5   col 4   col 3   col 2   col 1   col 0
---------     -------------------------------------------------------
Decimal       Binary encoding (unrepresented bits omitted) 
```

In addition to storing the location of each disc, we also store an array, `peaks` containing the location of where the next disc dropped in a column would fall. In the example below, the values of the `peaks` array is: `[1, 8, 17, 23, 29, 35, 42]`.
```
                   6 13 20 27 34 41 48
* * * * * * *      5 12 19 26 33 40 47
* * * * * * *      4 11 18 25 32 39 46
* * * * * * *      3 10 17 24 31 38 45
* * O * * * *      2  9 16 23 30 37 44
* * X O * * *      1  8 15 22 29 36 43
O X X X O * *      0  7 14 21 28 35 42
-------------     
0 1 2 3 4 5 6     
```

#### Making moves
With the combination of the `peaks` array and the bitboard representation, making a move is as simple as flipping the bit specified by the `peaks` array for the given column.

#### Checking for a win
**Coming soon*

### Connect4 AI
The Connect4 AI uses a simple Minimax game tree search with alpha-beta pruning.

#### Scoring function
**This section is a WIP**
Currently the scoring function is as follows:
```ruby
def score(depth)
  if AI_WON
    22 - depth
  elsif PLAYER_WON
    -(22 - depth)
  else
    0
  end
end
```

This is a simple scoring function that will eventually be improved with simple heuristics.

## Contributing
If you notice anything wrong or think of a cool new feature, please [open an issue](https://github.com/JonathanGin52/JonathanGin52/issues/new). Feel free to tag me with the text `cc: @jonathangin52` to make sure I see it.

**More details on how to contribute coming soon!**

## Acknowledgments
- This project was originally inspired by Tim Burgan's amazing [community chess tournament](https://github.com/timburgan/timburgan) project.
- The Connect4 game design was influenced by @denkspuren [bitboard design](https://github.com/denkspuren/BitboardC4/blob/main/BitboardDesign.md) document
