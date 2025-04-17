import conway/cell.{type Cell, Alive, Cell, Dead}
import conway/universe.{type Universe, Universe}

import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile

/// Configuration type to represent a starting pattern
pub type Configuration {
  Configuration(alive_cells: List(#(Int, Int)), width: Int)
}

/// Parse a configuration file and return a Configuration
/// The file format is:
/// - First line: width of the board
/// - Subsequent lines: x,y coordinates of alive cells
pub fn load_from_file(filename: String) -> Result(Configuration, String) {
  use content <- result.try(
    simplifile.read(filename)
    |> result.map_error(fn(_) { "Failed to read configuration file" }),
  )

  case
    string.split(content, "\n") |> list.filter(fn(l) { string.trim(l) != "" })
  {
    [] -> Error("Empty configuration file")
    [width_str, ..coord_lines] -> {
      use width <- result.try(
        int.parse(string.trim(width_str))
        |> result.map_error(fn(_) { "Invalid width specified" }),
      )

      use alive_cells <- result.try(parse_coordinates(coord_lines))

      Ok(Configuration(alive_cells: alive_cells, width: width))
    }
  }
}

/// Parse coordinate lines into a list of (x,y) tuples
fn parse_coordinates(lines: List(String)) -> Result(List(#(Int, Int)), String) {
  lines
  |> list.try_map(fn(line) {
    case string.split(string.trim(line), ",") {
      [x_str, y_str] -> {
        use x <- result.try(
          int.parse(string.trim(x_str))
          |> result.map_error(fn(_) { "Invalid x coordinate" }),
        )
        use y <- result.try(
          int.parse(string.trim(y_str))
          |> result.map_error(fn(_) { "Invalid y coordinate" }),
        )
        Ok(#(x, y))
      }
      _ -> Error("Invalid coordinate format, expected 'x,y'")
    }
  })
}

/// Create a universe from a configuration
pub fn create_universe_from_config(config: Configuration) -> Universe {
  let width = config.width
  let max_size = width * width

  // Create a board with all dead cells first
  let board_range = list.range(0, max_size - 1)
  let cells =
    list.map(board_range, fn(pos) {
      let x = pos % width
      let y = pos / width
      let life = Dead
      Cell(pos: pos, neighbors: create_neighbors(pos, width), life: life)
    })
  let board = dict.from_list(list.zip(board_range, cells))

  // Then mark specified cells as alive
  let board_with_alive =
    config.alive_cells
    |> list.fold(board, fn(acc, coord) {
      let #(x, y) = coord
      let pos = y * width + x

      case dict.get(acc, pos) {
        Ok(cell) -> {
          let updated_cell =
            Cell(
              pos: cell |> cell.get_pos,
              neighbors: cell |> cell.get_neighbors,
              life: Alive,
            )
          dict.insert(acc, pos, updated_cell)
        }
        Error(_) -> acc
        // Skip if position is invalid
      }
    })

  Universe(board: board_with_alive, width: width)
}

/// Save the current universe state to a file
pub fn save_to_file(universe: Universe, filename: String) -> Result(Nil, String) {
  let width = universe.width
  let alive_cells =
    universe.get_board(universe)
    |> dict.to_list
    |> list.filter(fn(pair) {
      let #(_, cell) = pair
      case cell {
        Cell(_, _, life) -> life == Alive
        _ -> False
      }
    })
    |> list.map(fn(pair) {
      let #(pos, _) = pair
      let x = pos % width
      let y = pos / width
      string.concat([int.to_string(x), ",", int.to_string(y)])
    })

  let content =
    string.concat([int.to_string(width), "\n", string.join(alive_cells, "\n")])

  simplifile.write(filename, content)
  |> result.map_error(fn(_) { "Failed to write configuration file" })
}

/// Create a list of neighbors for a cell at a given position
fn create_neighbors(pos: Int, width: Int) -> List(Int) {
  let x = pos % width
  let y = pos / width
  let neighbors = [
    #(x - 1, y - 1),
    #(x, y - 1),
    #(x + 1, y - 1),
    #(x - 1, y),
    #(x + 1, y),
    #(x - 1, y + 1),
    #(x, y + 1),
    #(x + 1, y + 1),
  ]

  neighbors
  |> list.filter(fn(coord) {
    let #(nx, ny) = coord
    nx >= 0 && nx < width && ny >= 0 && ny < width
  })
  |> list.map(fn(coord) {
    let #(nx, ny) = coord
    ny * width + nx
  })
}

/// Some predefined patterns that can be loaded without a file
pub fn glider(width: Int) -> Configuration {
  // A classic glider pattern
  Configuration(
    alive_cells: [#(1, 0), #(2, 1), #(0, 2), #(1, 2), #(2, 2)],
    width: width,
  )
}

pub fn blinker(width: Int) -> Configuration {
  // A simple oscillator
  Configuration(alive_cells: [#(1, 0), #(1, 1), #(1, 2)], width: width)
}

pub fn toad(width: Int) -> Configuration {
  // Another oscillator
  Configuration(
    alive_cells: [#(2, 1), #(3, 1), #(4, 1), #(1, 2), #(2, 2), #(3, 2)],
    width: width,
  )
}

pub fn pulsar(width: Int) -> Configuration {
  // A more complex oscillator
  let pattern = [
    #(2, 0),
    #(3, 0),
    #(4, 0),
    #(8, 0),
    #(9, 0),
    #(10, 0),
    #(0, 2),
    #(5, 2),
    #(7, 2),
    #(12, 2),
    #(0, 3),
    #(5, 3),
    #(7, 3),
    #(12, 3),
    #(0, 4),
    #(5, 4),
    #(7, 4),
    #(12, 4),
    #(2, 5),
    #(3, 5),
    #(4, 5),
    #(8, 5),
    #(9, 5),
    #(10, 5),
    #(2, 7),
    #(3, 7),
    #(4, 7),
    #(8, 7),
    #(9, 7),
    #(10, 7),
    #(0, 8),
    #(5, 8),
    #(7, 8),
    #(12, 8),
    #(0, 9),
    #(5, 9),
    #(7, 9),
    #(12, 9),
    #(0, 10),
    #(5, 10),
    #(7, 10),
    #(12, 10),
    #(2, 12),
    #(3, 12),
    #(4, 12),
    #(8, 12),
    #(9, 12),
    #(10, 12),
  ]

  Configuration(alive_cells: pattern, width: width)
}

pub fn gosper_glider_gun(width: Int) -> Configuration {
  // Gosper's Glider Gun - produces a glider every 30 generations
  let pattern = [
    // Left block
    #(1, 5),
    #(2, 5),
    #(1, 6),
    #(2, 6),
    // Left ship
    #(13, 3),
    #(14, 3),
    #(12, 4),
    #(16, 4),
    #(11, 5),
    #(17, 5),
    #(11, 6),
    #(15, 6),
    #(17, 6),
    #(18, 6),
    #(11, 7),
    #(17, 7),
    #(12, 8),
    #(16, 8),
    #(13, 9),
    #(14, 9),
    // Right ship
    #(25, 1),
    #(23, 2),
    #(25, 2),
    #(21, 3),
    #(22, 3),
    #(21, 4),
    #(22, 4),
    #(21, 5),
    #(22, 5),
    #(23, 6),
    #(25, 6),
    #(25, 7),
    // Right block
    #(35, 3),
    #(36, 3),
    #(35, 4),
    #(36, 4),
  ]

  Configuration(alive_cells: pattern, width: int.max(width, 40))
}

pub fn acorn(width: Int) -> Configuration {
  // Acorn - a methuselah pattern that stabilizes after 5206 generations
  let pattern = [#(1, 0), #(3, 1), #(0, 2), #(1, 2), #(4, 2), #(5, 2), #(6, 2)]

  // Center the pattern in the board
  let center_x = width / 2 - 3
  let center_y = width / 2 - 1

  let centered_pattern =
    pattern
    |> list.map(fn(coord) {
      let #(x, y) = coord
      #(x + center_x, y + center_y)
    })

  Configuration(alive_cells: centered_pattern, width: width)
}

pub fn r_pentomino(width: Int) -> Configuration {
  // R-pentomino - another methuselah pattern
  let pattern = [#(1, 0), #(2, 0), #(0, 1), #(1, 1), #(1, 2)]

  // Center the pattern in the board
  let center_x = width / 2 - 1
  let center_y = width / 2 - 1

  let centered_pattern =
    pattern
    |> list.map(fn(coord) {
      let #(x, y) = coord
      #(x + center_x, y + center_y)
    })

  Configuration(alive_cells: centered_pattern, width: width)
}

pub fn diehard(width: Int) -> Configuration {
  // Diehard - a pattern that disappears after 130 generations
  let pattern = [#(6, 0), #(0, 1), #(1, 1), #(1, 2), #(5, 2), #(6, 2), #(7, 2)]

  // Center the pattern in the board
  let center_x = width / 2 - 4
  let center_y = width / 2 - 1

  let centered_pattern =
    pattern
    |> list.map(fn(coord) {
      let #(x, y) = coord
      #(x + center_x, y + center_y)
    })

  Configuration(alive_cells: centered_pattern, width: width)
}
