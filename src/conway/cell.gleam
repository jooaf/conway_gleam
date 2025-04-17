import conway/utils
import gleam/function
import gleam/list
import prng/random

/// This represents if the current Cell is alive or Dead
pub type Life {
  Alive
  Dead
}

/// Custom Type that contains the alive and dead counts of a cell's neighbors.
pub type AliveDeadCounts {
  AliveDeadCounts(alive: Int, dead: Int)
}

/// A single cell. A cell can either be either be a Cell or an InvalidCell.
/// A Cell contains its' position on the board, the positions of its' neighbors, and its' life state.
pub type Cell {
  Cell(pos: Int, neighbors: List(Int), life: Life)
  InvalidCell
}

/// Wrapper type for an Int pair.
pub type Coordinate =
  #(Int, Int)

/// Get a Cell's position on the board.
pub fn get_pos(cell: Cell) -> Int {
  case cell {
    Cell(p, _, _) -> p
    // Return -1 for invalid cells
    _ -> -1
  }
}

/// Get a Cell's neighbors on the board.
pub fn get_neighbors(cell: Cell) -> List(Int) {
  case cell {
    Cell(_, n, _) -> n
    // Return -1 for invalid cells
    _ -> []
  }
}

/// Get a cell's neighbors.
pub fn to_int_neighbors(cell: Cell) -> List(Int) {
  case cell {
    Cell(_, n, _) -> n
    // Return empty list for invalid cells
    _ -> []
  }
}

/// Check if a cell is a Cell and is not an InvalidCell.
pub fn valid(cell: Cell) -> Result(Cell, Nil) {
  case cell {
    Cell(p, n, l) -> Ok(Cell(p, n, l))
    _ -> Error(Nil)
  }
}

/// Optimized function to count alive and dead neighbors
/// This is a performance-critical function, so we use a more efficient tail-recursive approach
pub fn alive_dead_counts(neighbors: List(Cell)) -> AliveDeadCounts {
  let #(alive, dead) = tail_rec_alive_dead_counts(neighbors, 0, 0)
  AliveDeadCounts(alive, dead)
}

fn tail_rec_alive_dead_counts(
  neighbors: List(Cell),
  alive_acc: Int,
  dead_acc: Int,
) -> #(Int, Int) {
  case neighbors {
    [] -> #(alive_acc, dead_acc)
    [Cell(_, _, life), ..rest] ->
      case life {
        Alive -> tail_rec_alive_dead_counts(rest, alive_acc + 1, dead_acc)
        Dead -> tail_rec_alive_dead_counts(rest, alive_acc, dead_acc + 1)
      }
    [InvalidCell, ..rest] ->
      tail_rec_alive_dead_counts(rest, alive_acc, dead_acc)
  }
}

/// Get a cell's current life state.
pub fn get_life_state_from_cell(cell: Cell) -> Life {
  case cell {
    Cell(_, _, l) -> l
    InvalidCell -> Dead
  }
}

/// Create a new cell by identifying its' neighbors by position
/// as well as randomly setting its Life state.
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

/// Create a new cell with a specified life state
pub fn new_cell_with_state(width: Int, pos: Int, state: Life) -> Cell {
  Cell(pos: pos, neighbors: create_neighbors(pos, width), life: state)
}

/// An optimized version of creating neighbors that directly computes the Moore neighborhood
/// without creating intermediate data structures
fn create_neighbors(pos: Int, width: Int) -> List(Int) {
  let x = pos % width
  let y = pos / width

  // Relative positions of neighbors in Moore neighborhood
  let neighbor_offsets = [
    #(-1, -1),
    #(0, -1),
    #(1, -1),
    #(-1, 0),
    #(1, 0),
    #(-1, 1),
    #(0, 1),
    #(1, 1),
  ]

  // Map offsets to absolute positions and filter out invalid ones
  neighbor_offsets
  |> list.filter_map(fn(offset) {
    let #(dx, dy) = offset
    let nx = x + dx
    let ny = y + dy

    // Check if neighbor is within bounds
    case nx >= 0 && nx < width && ny >= 0 && ny < width {
      True -> Ok(ny * width + nx)
      False -> Error(Nil)
    }
  })
}

/// Create a deep copy of a cell with a new life state
pub fn with_new_life_state(cell: Cell, new_state: Life) -> Cell {
  case cell {
    Cell(p, n, _) -> Cell(p, n, new_state)
    InvalidCell -> InvalidCell
  }
}

/// Calculate the next state of a cell based on its neighbors' states
/// This is a specialized version of the Conway's Game of Life rules
pub fn calculate_next_state(current_state: Life, alive_neighbors: Int) -> Life {
  case current_state, alive_neighbors {
    // A living cell with 2 or 3 living neighbors survives
    Alive, 2 | Alive, 3 -> Alive

    // A dead cell with exactly 3 living neighbors becomes alive
    Dead, 3 -> Alive

    // All other cells die or remain dead
    _, _ -> Dead
  }
}
