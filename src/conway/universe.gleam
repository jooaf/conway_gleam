import conway/cell.{type Cell, Alive, Cell, Dead, InvalidCell}
import conway/utils

import gleam/dict.{type Dict}
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/string

import colored

/// The Universe is where each cell will live.
/// The board field is a dict wrapper where the key is a position of a cell
/// and the value is the Cell type.
pub type Universe {
  Universe(board: Dict(Int, Cell), width: Int)
}

/// Given a Universe, return its board.
pub fn get_board(u: Universe) -> Dict(Int, Cell) {
  u.board
}

/// Given a Universe, return the width of the board.
pub fn get_width(u: Universe) -> Int {
  u.width
}

/// Given a Universe, return all of the positions.
pub fn get_board_pos(u: Universe) -> List(Int) {
  u
  |> get_board
  |> dict.to_list
  |> list.map(fn(a) { a.0 })
}

/// Given a Universe, return all cells.
pub fn get_board_cells(u: Universe) -> List(Cell) {
  u
  |> get_board
  |> dict.to_list
  |> list.map(fn(a) { a.1 })
}

/// Create a universe based on the width specified by the user
pub fn generate_universe(width: Int) -> Universe {
  let max_size = width * width
  let embed_size_new_cell_fn = function.curry2(cell.new_cell)
  let board_range = list.range(0, max_size - 1)
  let cell_range = list.map(board_range, embed_size_new_cell_fn(width))
  let board = dict.from_list(list.zip(board_range, cell_range))
  Universe(board: board, width: width)
}

/// Create a new universe based on a list of updated cells. 
/// This function is used to generate a new Universe state.
pub fn new_board(u: Universe, update_cells: List(Cell)) -> Universe {
  let pos_list = dict.keys(u.board)
  let pos_cells_list = list.zip(pos_list, update_cells)
  let width = get_width(u)
  let new_board = dict.from_list(pos_cells_list)
  Universe(board: new_board, width: width)
}

/// Print the current state of the Universe.
pub fn print_board(u: Universe, cell_size: Int) -> Nil {
  let neighbors = get_board_cells(u)
  let width = get_width(u)
  let color_state_fn = fn(cell) {
    case cell {
      Cell(_, _, state) -> {
        case state {
          Alive -> colored.red(string.repeat("█", cell_size))
          _ -> colored.green(string.repeat("_", cell_size))
        }
      }
      InvalidCell -> ""
    }
  }
  let _ =
    neighbors
    |> utils.list_to_square_matrix(width)
    |> utils.map_2d_matrix(color_state_fn)
    |> list.map(fn(row) { io.println(string.join(row, "")) })
  io.println("")
}

fn get_neighbors_rec(n: List(Result(Cell, Nil))) -> List(Cell) {
  let eval_fn = fn(c) {
    case c {
      Ok(v) -> v
      Error(_) -> InvalidCell
    }
  }

  case n {
    [] -> []
    [c] -> {
      // filter out invalid cell states
      case eval_fn(c) == InvalidCell {
        True -> []
        False -> [eval_fn(c)]
      }
    }
    [c, ..rest] -> list.concat([[eval_fn(c)], get_neighbors_rec(rest)])
  }
}

/// Given a Cell, find its' neighbors via the Universe's board.
pub fn get_neighbors(
  cell: Cell,
  universe: Universe,
) -> Result(List(Cell), String) {
  // if suddenly an invalid state occurs 
  let #(pos, neighbors) = case cell {
    cell.Cell(p, neigh, _) -> #(p, neigh)
    // TODO: fix negative case, hack
    _ -> #(-1, [])
  }
  let neighbors_to_cells =
    list.map(neighbors, fn(c) { dict.get(universe.board, c) })

  case get_neighbors_rec(neighbors_to_cells) {
    [] ->
      Error(
        "Cells should always have neighbors. Error with cell: "
        <> int.to_string(pos),
      )
    alist -> Ok(alist)
  }
}

/// Update a cell's living or dead state based on these rules: 
/// 1. Any live cell with fewer than two live neighbours dies, as if caused by underpopulation.
/// 2. Any live cell with two or three live neighbours lives on to the next generation.
/// 3. Any live cell with more than three live neighbours dies, as if by overpopulation.
/// 4. Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
pub fn update_cell(u: Universe, cell: Cell) -> Cell {
  let assert Ok(cell) = cell.valid(cell)
  let assert Ok(n) = get_neighbors(cell, u)
  let life = case cell.get_life_state_from_cell(cell) {
    Alive -> {
      let counts = cell.alive_dead_counts(n)
      case counts.alive == 2 || counts.alive == 3 {
        True -> Alive
        False -> Dead
      }
    }
    cell.Dead -> {
      let counts = cell.alive_dead_counts(n)
      case counts.alive == 3 {
        True -> Alive
        False -> Dead
      }
    }
  }
  let c = Cell(cell.get_pos(cell), cell.to_int_neighbors(cell), life)
  c
}
