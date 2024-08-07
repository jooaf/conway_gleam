import gleam/dict.{type Dict}
import gleam/float
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/set
import prng/random

pub type Life {
  Alive
  Dead
}

pub type AliveDeadCounts {
  AliveDeadCounts(alive: Int, dead: Int)
}

pub type Cell {
  Cell(pos: Int, neighbors: List(Int), life: Life)
  InvalidCell
}

pub type Universe {
  Universe(board: Dict(Int, Cell), width: Int)
}

fn get_board(u: Universe) -> Dict(Int, Cell) {
  u.board
}

fn get_width(u: Universe) -> Int {
  u.width
}

pub fn get_board_pos(u: Universe) -> List(Int) {
  u
  |> get_board
  |> dict.to_list
  |> list.map(fn(a) { a.0 })
}

pub fn get_board_cells(u: Universe) -> List(Cell) {
  u
  |> get_board
  |> dict.to_list
  |> list.map(fn(a) { a.1 })
}

pub fn new_board(u: Universe, update_cells: List(Cell)) -> Universe {
  let pos_list = dict.keys(u.board)
  let pos_cells_list = list.zip(pos_list, update_cells)
  let width = get_width(u)
  let new_board = dict.from_list(pos_cells_list)
  Universe(board: new_board, width: width)
}

fn print_neighbor_rec(cells: List(Cell), width: Int) -> Nil {
  let print_state_fn = fn(state) {
    case state {
      Alive -> "*"
      _ -> "a"
    }
  }

  case cells {
    [] -> Nil
    // [Cell(p, _, l)] -> {
    //   print_state_fn(l)
    //   println_fn(p)
    // }
    [a, b, c, d] -> {
      let line = {
        print_state_fn(get_life_state_from_cell(a))
        <> print_state_fn(get_life_state_from_cell(b))
        <> print_state_fn(get_life_state_from_cell(c))
        <> print_state_fn(get_life_state_from_cell(d))
      }
      io.println(line)
    }
    [a, b, c, d, ..rest] -> {
      // print_state_fn(l)
      // println_fn(p)

      let line = {
        print_state_fn(get_life_state_from_cell(a))
        <> print_state_fn(get_life_state_from_cell(b))
        <> print_state_fn(get_life_state_from_cell(c))
        <> print_state_fn(get_life_state_from_cell(d))
      }
      io.println(line)
      print_neighbor_rec(rest, width)
    }
    _ -> Nil
  }
}

pub fn print_board(u: Universe) -> Nil {
  let neighbors = get_board_cells(u)
  let width = get_width(u)
  print_neighbor_rec(neighbors, width)
  io.println("")
}

pub fn get_life_state_from_cell(cell: Cell) -> Life {
  case cell {
    Cell(_, _, l) -> l
    InvalidCell -> Dead
  }
}

fn remove_invalid_neighbors(
  neighbors: List(Int),
  pos: Int,
  max_size: Int,
) -> List(Int) {
  // filter any negatives or values that exceed the universe boundary
  list.filter(neighbors, fn(cell_pos) {
    cell_pos >= 0 && cell_pos <= max_size - 1 && cell_pos != pos
  })
}

fn top_row_neighbors(pos: Int, max_size: Int) -> List(Int) {
  let assert Ok(width) = int.square_root(max_size)
  let width = float.truncate(width)

  let potential_neighbors = [
    { pos - width },
    { pos - width + 1 },
    { pos - width - 1 },
  ]

  remove_invalid_neighbors(potential_neighbors, pos, max_size)
}

fn bottom_row_neighbors(pos: Int, max_size: Int) -> List(Int) {
  let assert Ok(width) = int.square_root(max_size)
  let width = float.truncate(width)

  let potential_neighbors = [
    { pos + width },
    { pos + width + 1 },
    { pos + width - 1 },
  ]

  remove_invalid_neighbors(potential_neighbors, pos, max_size)
}

fn row_neighbors(pos: Int, max_size: Int) -> List(Int) {
  let potential_neighbors = [{ pos + 1 }, { pos - 1 }]

  remove_invalid_neighbors(potential_neighbors, pos, max_size)
}

pub fn create_neighbors(pos: Int, max_size: Int) -> List(Int) {
  let combined_list =
    list.concat([
      row_neighbors(pos, max_size),
      top_row_neighbors(pos, max_size),
      bottom_row_neighbors(pos, max_size),
    ])

  let set_list = set.from_list(combined_list)
  set.to_list(set_list)
}

pub fn new_cell(max_size: Int, pos: Int) -> Cell {
  let life_state =
    random.int(0, 1)
    |> random.map(fn(a) {
      case a {
        0 -> Dead
        1 -> Alive
        _ -> Dead
      }
    })
    |> random.random_sample
  Cell(pos: pos, neighbors: create_neighbors(pos, max_size), life: life_state)
}

pub fn generate_universe(width: Int) -> Universe {
  let max_size = width * width
  let embed_size_new_cell_fn = function.curry2(new_cell)
  let board_range = list.range(0, max_size - 1)
  let cell_range = list.map(board_range, embed_size_new_cell_fn(max_size))
  let board = dict.from_list(list.zip(board_range, cell_range))
  Universe(board: board, width: width)
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

pub fn get_pos(cell: Cell) -> Int {
  // if suddenly an invalid state occurs 
  case cell {
    Cell(p, _, _) -> p
    // TODO: fix negative case, hack
    _ -> -1
  }
}

pub fn to_int_neighbors(cell: Cell) -> List(Int) {
  // if suddenly an invalid state occurs 
  case cell {
    Cell(_, n, _) -> n
    // TODO: fix negative case, hack
    _ -> []
  }
}

pub fn get_neighbors(
  cell: Cell,
  universe: Universe,
) -> Result(List(Cell), String) {
  // if suddenly an invalid state occurs 
  let #(pos, neighbors) = case cell {
    Cell(p, neigh, _) -> #(p, neigh)
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

pub fn valid(cell: Cell) -> Result(Cell, Nil) {
  case cell {
    Cell(p, n, l) -> Ok(Cell(p, n, l))
    _ -> Error(Nil)
  }
}

fn tail_rec_alive_dead_counts(
  n: List(Cell),
  alive: Int,
  dead: Int,
) -> #(Int, Int) {
  case n {
    [] -> #(0, 0)
    [Cell(_, _, l), ..rest] ->
      case l {
        Alive -> {
          let alive = alive + 1
          tail_rec_alive_dead_counts(rest, alive, dead)
        }
        Dead -> {
          let dead = dead + 1
          tail_rec_alive_dead_counts(rest, alive, dead)
        }
      }
    _ -> #(0, 0)
  }
}

fn alive_dead_counts(neighbors: List(Cell)) -> AliveDeadCounts {
  let #(alive, dead) = tail_rec_alive_dead_counts(neighbors, 0, 0)
  AliveDeadCounts(alive, dead)
}

pub fn update_cell(u: Universe, cell: Cell) -> Cell {
  let assert Ok(cell) = valid(cell)
  let assert Ok(n) = get_neighbors(cell, u)
  let life = case get_life_state_from_cell(cell) {
    Alive -> {
      let counts = alive_dead_counts(n)
      case counts.alive == 2 || counts.alive == 3 {
        True -> Alive
        False -> Dead
      }
    }
    Dead -> {
      let counts = alive_dead_counts(n)
      case counts.alive == 3 {
        True -> Alive
        False -> Dead
      }
    }
  }
  let c = Cell(get_pos(cell), to_int_neighbors(cell), life)
  io.debug(c)
  c
}

pub fn loop(u: Universe, iterations: Int) -> Nil {
  let start = iterations
  // io.debug(start)
  case iterations {
    0 -> Nil
    i -> {
      print_board(u)
      let uni_update = function.curry2(update_cell)

      // io.debug(get_board_cells(u))
      let cells = get_board_cells(u) |> list.map(fn(a) { uni_update(u)(a) })
      let u = new_board(u, cells)
      // print_board(u)
      loop(u, i - 1)
    }
  }
}

pub fn main() {
  io.println("Hello from conway_life!")
  let u = generate_universe(4)
  // print_board(u)
  // io.println("")
  // io.print("\n")
  loop(u, 2)
}
