import colored
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/result
import gleam/string

import gleam/function
import gleam/int
import gleam/io
import gleam/list
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

pub type Coordinate =
  #(Int, Int)

pub type PotentialNeighborPoint {
  PotentialNeighborPoint(dx: Int, dy: Int, nx: Int, ny: Int)
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

pub fn map_2d_matrix_with_state(
  matrix: List(List(a)),
  map_fn: fn(a, List(List(a))) -> b,
) -> List(List(b)) {
  list.map(matrix, fn(row) {
    list.map(row, fn(value) { map_fn(value, matrix) })
  })
}

pub fn map_2d_matrix(matrix: List(List(a)), map_fn: fn(a) -> b) -> List(List(b)) {
  list.map(matrix, fn(row) { list.map(row, map_fn) })
}

pub fn list_to_square_matrix(l: List(a), n: Int) -> List(List(a)) {
  case l {
    [] -> []
    _ -> {
      let row = list.take(l, n)
      let rest = list.drop(l, n)
      [row, ..list_to_square_matrix(rest, n)]
    }
  }
}

pub fn print_board(u: Universe) -> Nil {
  // TODO: put in string repeat to make universe bigger
  let neighbors = get_board_cells(u)
  let width = get_width(u)
  let color_state_fn = fn(cell) {
    case cell {
      Cell(_, _, state) -> {
        case state {
          Alive -> colored.red("████")
          _ -> colored.green("____")
          // _ -> ""
        }
      }
      InvalidCell -> ""
    }
  }
  let _ =
    neighbors
    |> list_to_square_matrix(width)
    |> map_2d_matrix(color_state_fn)
    |> list.map(fn(row) { io.println(string.join(row, "")) })
  io.println("")
}

pub fn get_life_state_from_cell(cell: Cell) -> Life {
  case cell {
    Cell(_, _, l) -> l
    InvalidCell -> Dead
  }
}

fn remove_invalid_neighbors(
  n neighbors: List(Int),
  p pos: Int,
  max max_size: Int,
) -> List(Int) {
  // filter any negatives or values that exceed the universe boundary
  list.filter(neighbors, fn(cell_pos) {
    cell_pos >= 0 && cell_pos <= max_size - 1 && cell_pos != pos
  })
}

pub fn build_product_fn(other: List(Int), x: Int) -> List(#(Int, Int)) {
  case other {
    [] -> []
    [o, ..rest] -> [#(x, o), ..build_product_fn(rest, x)]
  }
}

fn filter_invalid_more_neighboorhood(
  width: Int,
  potential: PotentialNeighborPoint,
) -> Bool {
  case potential {
    PotentialNeighborPoint(dx, dy, nx, ny)
      if { dx != 0 || dy != 0 }
      && 0 <= nx
      && nx <= width
      && 0 <= ny
      && ny <= width
    -> True
    _ -> False
  }
}

fn nx_ny_creation(x: Int, y: Int, pos: List(Coordinate)) -> List(Coordinate) {
  case pos {
    [] -> []
    [p, ..rest] -> [#(x + p.0, y + p.1), ..nx_ny_creation(x, y, rest)]
  }
}

fn create_potential_points_rec(
  zip_coor_list: List(#(Coordinate, Coordinate)),
) -> List(PotentialNeighborPoint) {
  case zip_coor_list {
    [] -> []
    [#(d, n), ..rest] -> [
      PotentialNeighborPoint(d.0, d.1, n.0, n.1),
      ..create_potential_points_rec(rest)
    ]
  }
}

fn create_potential_points(
  derivations: List(Coordinate),
  n: List(Coordinate),
) -> List(PotentialNeighborPoint) {
  let assert True = list.length(derivations) == list.length(n)

  let zip_coor_list = list.zip(derivations, n)
  create_potential_points_rec(zip_coor_list)
}

fn moore_neighborhood(x: Int, y: Int, width: Int) -> List(Int) {
  let n_pos = [-1, 0, 1]
  let cross_n = function.curry2(build_product_fn)(n_pos)

  let n_pos_cross =
    n_pos
    |> list.map(fn(x) { cross_n(x) })
    |> list.flatten

  let nx_ny_list = nx_ny_creation(x, y, n_pos_cross)
  let pot = create_potential_points(n_pos_cross, nx_ny_list)
  let filter_points = function.curry2(filter_invalid_more_neighboorhood)(width)
  pot
  |> list.filter(filter_points)
  |> list.map(fn(p) { p.ny * width + p.nx })
}

pub fn create_neighbors(pos: Int, width: Int) -> List(Int) {
  let x = pos % width
  let y = pos / width
  let final_list = moore_neighborhood(x, y, width)

  remove_invalid_neighbors(n: final_list, p: pos, max: width * width)
}

pub fn new_cell(width: Int, pos: Int) -> Cell {
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
  Cell(pos: pos, neighbors: create_neighbors(pos, width), life: life_state)
}

pub fn generate_universe(width: Int) -> Universe {
  let max_size = width * width
  let embed_size_new_cell_fn = function.curry2(new_cell)
  let board_range = list.range(0, max_size - 1)
  let cell_range = list.map(board_range, embed_size_new_cell_fn(width))
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
    [] -> #(alive, dead)
    [Cell(_, _, l), ..rest] ->
      case l {
        Alive -> {
          let update_alive = alive + 1
          tail_rec_alive_dead_counts(rest, update_alive, dead)
        }
        Dead -> {
          let update_dead = dead + 1
          tail_rec_alive_dead_counts(rest, alive, update_dead)
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
  c
}

pub fn loop(u: Universe, iterations: Int, fps: Int) -> Nil {
  case iterations {
    0 -> Nil
    i -> {
      print_board(u)
      let uni_update = function.curry2(update_cell)
      let cells = get_board_cells(u) |> list.map(fn(a) { uni_update(u)(a) })
      let u = new_board(u, cells)
      process.sleep(fps)

      clear_output()
      process.sleep(10)
      loop(u, i - 1, fps)
    }
  }
}

@external(erlang, "Elixir.ShellUtils", "run_command")
pub fn run_command(
  command: String,
  args: List(String),
) -> Result(String, #(Int, String))

pub fn execute(command: String, args: List(String)) -> Result(String, String) {
  run_command(command, args)
  |> result.map_error(fn(stat) {
    "Command failed with status " <> int.to_string(stat.0) <> ": " <> stat.1
  })
}

pub fn clear_output() -> Nil {
  // io.debug(execute("nu", ["-c", "clear"]) |> result.unwrap(""))
  // for speed purposes i will run the string output that is generated
  // from running the clear shell command via elixir 
  io.print("\u{001B}[2J\u{001B}[1;1H")
  Nil
}

pub fn main() {
  let fps = 400
  io.println("Hello from conway_life!")
  let u = generate_universe(40)
  loop(u, 400, fps)
}
