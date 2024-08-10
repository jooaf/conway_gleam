import gleam/list

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

/// Used to create a cartesian product for one item with a list
/// i.e.  5, [6,7,8] -> [(5,6), (5,7), (5,8)] 
pub fn build_product_fn(other: List(Int), x: Int) -> List(#(Int, Int)) {
  case other {
    [] -> []
    [o, ..rest] -> [#(x, o), ..build_product_fn(rest, x)]
  }
}
