(* [board] is a 2-D list of char options representing the board *)
type board = (char option) list list

(* [bonus_letter_tiles] is a list of pairs mapping tiles to letter multipliers,
  if a tile is not included in this list it has a letter multiplier of 1 *)
val bonus_letter_tiles : ((int * int) * int) list

(* [bonus_word_tiles] is a list of pairs mapping tiles to word multipliers,
  if a tile is not included in this list it has a word multipler of 1 *)
val bonus_word_tiles : ((int * int) * int) list

(* [empty] is the empty board *)
val empty : board

(* gets the diff between two boards in terms of chars added *)
val get_diff : board -> board -> char list

(* [is_empty board row col] is true if the coordinate ([row],[col] is empty in
 * the [board] *)
val is_empty : board -> int -> int -> bool

(* [get_tile board row col] is a char option representing the tile at the
 * coordinate ([row],[col]) in the [board] *)
val get_tile : board -> int -> int -> char option

(* [place board row col value] is a new board with the character [value] placed
 * at the coordinate ([row],[col]) in the [board] *)
val place : board -> int -> int -> char -> board

(* return bonus at specific coordinate. return 1 if no bonus *)
val bonus_letter_at : int * int -> int

val bonus_word_at : int * int -> int

(* [neighbors] contains a set of four tiles adjacent to a central tile *)
type neighbors = {
  top : char option;
  bottom : char option;
  left : char option;
  right : char option;
}

(* [get_neighbors board row col] is the set of four tiles adjacent to the tile
 * at the coordinate ([row],[col]) in the [board] *)
val get_neighbors : board -> int -> int -> neighbors

val to_json : board -> string

val from_json : Yojson.Basic.json -> board
