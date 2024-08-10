import conway/universe.{type Universe}

import gleam/erlang/process
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/result

import argv

import glint

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
  // note i am using nushell here. if you find that there are issues
  // please uncomment the io.print command above Nil
  io.print(execute("nu", ["-c", "clear"]) |> result.unwrap(""))
  // for speed purposes i will run the string output that is generated
  // from running the clear shell command via elixir 
  // io.print("\u{001B}[2J\u{001B}[1;1H")
  Nil
}

// this function returns the builder for the iter option 
fn iter_option() -> glint.Flag(Int) {
  glint.int_flag("n_iter")
  |> glint.flag_default(20)
  |> glint.flag_help("Number of iterations to run the simulation")
}

// this function returns the builder for the iter option 
fn board_size() -> glint.Flag(Int) {
  glint.int_flag("board_size")
  |> glint.flag_default(3)
  |> glint.flag_help("n x n size of the board")
}

// this function returns the builder for the size of the cell option 
fn size_of_cell() -> glint.Flag(Int) {
  glint.int_flag("cell_size")
  |> glint.flag_default(2)
  |> glint.flag_help("Size of the cell")
}

/// the glint command that will be executed
fn start_conway_life() -> glint.Command(Nil) {
  use <- glint.command_help("Welcome to Conway's Game of Life!")

  use n_iter <- glint.flag(iter_option())
  use board_size <- glint.flag(board_size())
  use cell_size <- glint.flag(size_of_cell())

  use _, _, flags <- glint.command()
  let assert Ok(n_iter) = n_iter(flags)
  let assert Ok(board_size) = board_size(flags)
  let assert Ok(size_of_cell) = cell_size(flags)

  let ms_delay = 400
  io.println("Hello from conway_life!")
  let u = universe.generate_universe(board_size)
  loop(u, n_iter, ms_delay, size_of_cell)
}

pub fn loop(u: Universe, iterations: Int, fps: Int, cell_size) -> Nil {
  case iterations {
    0 -> Nil
    i -> {
      universe.print_board(u, cell_size)
      let uni_update = function.curry2(universe.update_cell)
      let cells =
        universe.get_board_cells(u) |> list.map(fn(a) { uni_update(u)(a) })
      let u = universe.new_board(u, cells)
      process.sleep(fps)

      clear_output()
      process.sleep(10)
      loop(u, i - 1, fps, cell_size)
    }
  }
}

pub fn main() {
  glint.new()
  |> glint.with_name("conway_life")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: start_conway_life())
  |> glint.run(argv.load().arguments)
}
