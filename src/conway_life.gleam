import conway/cell.{type Life}
import conway/config_loader.{type Configuration}
import conway/universe.{type Universe}
import gleam/dict.{type Dict}

import gleam/erlang/process
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

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
  // note i am using nushell here. If you find that there are issues
  // please uncomment the io.print command below Nil
  io.print(execute("nu", ["-c", "clear"]) |> result.unwrap(""))
  // for speed purposes I will run the string output that is generated
  // from running the clear shell command via elixir 
  // io.print("\u{001B}[2J\u{001B}[1;1H")
  Nil
}

// This function returns the builder for the iter option 
fn iter_option() -> glint.Flag(Int) {
  glint.int_flag("n_iter")
  |> glint.flag_default(20)
  |> glint.flag_help("Number of iterations to run the simulation")
}

// This function returns the builder for the board size option 
fn board_size() -> glint.Flag(Int) {
  glint.int_flag("board_size")
  |> glint.flag_default(15)
  |> glint.flag_help("n x n size of the board")
}

// This function returns the builder for the size of the cell option 
fn size_of_cell() -> glint.Flag(Int) {
  glint.int_flag("cell_size")
  |> glint.flag_default(2)
  |> glint.flag_help("Size of the cell when displaying")
}

// This function returns the builder for the frame delay option
fn frame_delay() -> glint.Flag(Int) {
  glint.int_flag("delay")
  |> glint.flag_default(200)
  |> glint.flag_help("Delay between frames in milliseconds")
}

// This function returns the builder for the config file option
fn config_file() -> glint.Flag(String) {
  glint.string_flag("config")
  |> glint.flag_help("Path to a configuration file")
}

// This function returns the builder for the built-in pattern option
fn pattern() -> glint.Flag(String) {
  glint.string_flag("pattern")
  |> glint.flag_help(
    "Name of built-in pattern (glider, blinker, toad, pulsar, gosper_glider_gun, acorn, r_pentomino, diehard, random)",
  )
}

// This function returns the builder for the save file option
fn save_file() -> glint.Flag(String) {
  glint.string_flag("save")
  |> glint.flag_help("Path to save the final state")
}

/// The glint command that will be executed
fn start_conway_life() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Welcome to Conway's Game of Life!

This simulation implements Conway's Game of Life, a cellular automaton
devised by mathematician John Conway in 1970.

Rules:
1. Any live cell with fewer than two live neighbors dies (underpopulation)
2. Any live cell with two or three live neighbors lives on
3. Any live cell with more than three live neighbors dies (overpopulation)
4. Any dead cell with exactly three live neighbors becomes a live cell (reproduction)

You can:
- Load a predefined pattern with --pattern=[name]
  Available patterns:
  - glider: A simple glider that moves diagonally
  - blinker: A simple oscillator
  - toad: A period-2 oscillator
  - pulsar: A period-3 oscillator
  - gosper_glider_gun: Gosper's glider gun (produces gliders)
  - acorn: A methuselah pattern that stabilizes after 5206 generations
  - r_pentomino: Another methuselah pattern
  - diehard: A pattern that disappears after 130 generations
  - random: A random initial configuration

- Load a custom configuration with --config=[file]
- Save the final state with --save=[file]
- Adjust the board size with --board_size=[n]
- Set the number of iterations with --n_iter=[n]
- Change the display size with --cell_size=[n]
- Adjust the animation speed with --delay=[ms]

The simulation automatically detects stable states and oscillators.",
  )

  use n_iter <- glint.flag(iter_option())
  use board_size <- glint.flag(board_size())
  use cell_size <- glint.flag(size_of_cell())
  use delay <- glint.flag(frame_delay())
  use config <- glint.flag(config_file())
  use pattern <- glint.flag(pattern())
  use save <- glint.flag(save_file())

  use _, _, flags <- glint.command()
  let assert Ok(n_iter) = n_iter(flags)
  let assert Ok(board_size) = board_size(flags)
  let assert Ok(cell_size) = cell_size(flags)
  let assert Ok(frame_delay) = delay(flags)

  // Initialize universe based on options
  let u = case config(flags), pattern(flags) {
    Ok(file_path), _ -> {
      // Load configuration from file if specified
      case config_loader.load_from_file(file_path) {
        Ok(config) -> {
          io.println("Loaded configuration from: " <> file_path)
          config_loader.create_universe_from_config(config)
        }
        Error(e) -> {
          io.println("Error loading configuration: " <> e)
          io.println("Falling back to random universe")
          universe.generate_universe(board_size)
        }
      }
    }
    _, Ok(pattern_name) -> {
      // Load a predefined pattern if specified
      case string.lowercase(pattern_name) {
        "glider" -> {
          io.println("Using glider pattern")
          config_loader.glider(board_size)
          |> config_loader.create_universe_from_config()
        }
        "blinker" -> {
          io.println("Using blinker pattern")
          config_loader.blinker(board_size)
          |> config_loader.create_universe_from_config()
        }
        "toad" -> {
          io.println("Using toad pattern")
          config_loader.toad(board_size)
          |> config_loader.create_universe_from_config()
        }
        "pulsar" -> {
          io.println("Using pulsar pattern")
          config_loader.pulsar(board_size)
          |> config_loader.create_universe_from_config()
        }
        "gosper_glider_gun" | "gun" -> {
          io.println("Using Gosper glider gun pattern")
          config_loader.gosper_glider_gun(board_size)
          |> config_loader.create_universe_from_config()
        }
        "acorn" -> {
          io.println("Using acorn pattern (methuselah)")
          config_loader.acorn(board_size)
          |> config_loader.create_universe_from_config()
        }
        "r_pentomino" | "rpentomino" -> {
          io.println("Using R-pentomino pattern (methuselah)")
          config_loader.r_pentomino(board_size)
          |> config_loader.create_universe_from_config()
        }
        "diehard" -> {
          io.println("Using diehard pattern")
          config_loader.diehard(board_size)
          |> config_loader.create_universe_from_config()
        }
        "random" | _ -> {
          io.println("Using random pattern")
          universe.generate_universe(board_size)
        }
      }
    }
    _, _ -> {
      // Default to random universe
      io.println("Using random universe")
      universe.generate_universe(board_size)
    }
  }

  // Run the simulation
  io.println("Starting Conway's Game of Life simulation...")
  io.println(
    "Board size: "
    <> int.to_string(board_size)
    <> "x"
    <> int.to_string(board_size),
  )
  io.println("Cell size: " <> int.to_string(cell_size))
  io.println("Iterations: " <> int.to_string(n_iter))
  io.println("Delay: " <> int.to_string(frame_delay) <> "ms")
  io.println("Press Ctrl+C to exit")
  io.println("")

  // Run the simulation loop
  let final_universe = loop(u, n_iter, frame_delay, cell_size)

  // Save final state if requested
  case save(flags) {
    Ok(save_path) -> {
      io.println("Saving final state to: " <> save_path)
      case config_loader.save_to_file(final_universe, save_path) {
        Ok(_) -> io.println("State saved successfully")
        Error(e) -> io.println("Error saving state: " <> e)
      }
    }
    _ -> Nil
  }
}

/// Maximum number of previous states to remember for cycle detection
const max_history_size = 10

/// Type to track previous states for detecting cycles
type StateHistory =
  List(#(Dict(Int, Life), Int))

// Tuple of board state and generation number

/// Convert a universe board to a simplified state for cycle detection
fn get_state_snapshot(u: Universe) -> Dict(Int, Life) {
  u.board
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(pos, cell) = pair
    #(pos, cell.get_life_state_from_cell(cell))
  })
  |> dict.from_list
}

/// Check if the current state matches any previous state in history
fn detect_cycle(
  current_state: Dict(Int, Life),
  history: StateHistory,
  current_gen: Int,
) -> Result(Int, Nil) {
  // Look for a matching state in history
  history
  |> list.find(fn(entry) {
    let #(state, _) = entry
    dict.to_list(state) == dict.to_list(current_state)
  })
  |> result.map(fn(match) {
    let #(_, gen) = match
    current_gen - gen
    // Return the cycle length
  })
}

/// Main simulation loop with cycle detection
pub fn loop(u: Universe, iterations: Int, fps: Int, cell_size: Int) -> Universe {
  loop_with_history(u, iterations, fps, cell_size, [], 1)
}

/// Internal recursive function with state history
fn loop_with_history(
  u: Universe,
  iterations: Int,
  fps: Int,
  cell_size: Int,
  history: StateHistory,
  generation: Int,
) -> Universe {
  case iterations {
    0 -> u
    // Return the final universe state
    i -> {
      // Display current state
      universe.print_board(u, cell_size)

      // Get current state snapshot for cycle detection
      let current_state = get_state_snapshot(u)

      // Check for cycle
      case detect_cycle(current_state, history, generation) {
        Ok(cycle_length) -> {
          // We found a cycle
          io.println(
            string.concat([
              "Detected a ",
              case cycle_length {
                1 -> "stable state"
                n -> string.concat(["cycle with period ", int.to_string(n)])
              },
              " at generation ",
              int.to_string(generation),
            ]),
          )
          process.sleep(2000)
          // Pause to show the message
          u
          // Return current state
        }
        Error(_) -> {
          // Calculate next generation
          let uni_update = function.curry2(universe.update_cell)
          let cells =
            universe.get_board_cells(u) |> list.map(fn(a) { uni_update(u)(a) })
          let new_u = universe.new_board(u, cells)

          // Update history, keeping only the last max_history_size states
          let updated_history =
            [#(current_state, generation), ..history]
            |> list.take(max_history_size)

          // Delay between frames for visualization
          process.sleep(fps)

          // Clear screen for next frame
          clear_output()
          process.sleep(10)

          // Continue with next iteration
          loop_with_history(
            new_u,
            i - 1,
            fps,
            cell_size,
            updated_history,
            generation + 1,
          )
        }
      }
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
