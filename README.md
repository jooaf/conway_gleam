# conway_life
My first project in Gleam :) ! This is my attempt of writing 
Conway's Game of Life in Gleam.

![conway](https://github.com/user-attachments/assets/260e954c-d174-4a11-892e-35d687e42304)

## Running program 
To run the program, please clone this repo and run these commands 
```sh
git clone https://github.com/jooaf/conway_gleam.git 
cd conway_gleam 
gleam run
```
Note: You will need to have [Elixir](https://elixir-lang.org/cases.html) installed on your machine.


## CLI 
```sh
Welcome to Conway's Game of Life!

USAGE:
    conway_life [ ARGS ] [ --board_size=<INT> --cell_size=<INT> --n_iter=<INT> ]

FLAGS:
    --board_size=<INT>    n x n size of the board
    --cell_size=<INT>     Size of the cell
    --help                Print help information
    --n_iter=<INT>        Number of iterations to run the simulation  
```

Here is an example of how to run the program 
```sh
gleam run -- --board_size=40 --cell_size=4 --n_iter=50    
```


