import conway/utils
import gleam/function
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

pub type Coordinate =
  #(Int, Int)

pub type PotentialNeighborPoint {
  PotentialNeighborPoint(dx: Int, dy: Int, nx: Int, ny: Int)
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

pub fn alive_dead_counts(neighbors: List(Cell)) -> AliveDeadCounts {
  let #(alive, dead) = tail_rec_alive_dead_counts(neighbors, 0, 0)
  AliveDeadCounts(alive, dead)
}

pub fn get_life_state_from_cell(cell: Cell) -> Life {
  case cell {
    Cell(_, _, l) -> l
    InvalidCell -> Dead
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
  let cross_n = function.curry2(utils.build_product_fn)(n_pos)

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

fn create_neighbors(pos: Int, width: Int) -> List(Int) {
  let x = pos % width
  let y = pos / width
  let final_list = moore_neighborhood(x, y, width)

  remove_invalid_neighbors(n: final_list, p: pos, max: width * width)
}
