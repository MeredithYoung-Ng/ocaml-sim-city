type resource =
  | Dining of int*int list
  | Lecture of int*int list
  | Power of int*int list
type terrain = Water | Forest | Clear | Gorges
type disaster = Fire | Blizzard | Prelim
type building_type =
  | Dorm of int*int list
  | Resource of resource
  | Road
  | Pline (*power lines*)
  | Section of int*int
  | Empty

(* [square] is a type representing the current state of an individual game square. It contains information pertaining to what is currently on the square (represented by field btype), and also attributes that are dependent on btype (ex. maintenance_cost, level). Finally, this type also keeps track of "natural" and "static" information about the square itself, such as its x and y coordinates and terrain features. *)
type square = {
  btype : building_type;
  level : int;
  xcoord : int;
  ycoord : int;
  maintenance_cost : int;
  terrain : terrain;

}

(* [gamestate] is a type representing the state of an adventure. It contains all the information necessary to recreate the current state of the game, including overall information (current money, happiness etc) and individual square information (what is current built on each square, resource connections, etc). The overall game information is stored as record fields, while the square information is stored as a 2D array of type square elements. *)
type gamestate = {
  disaster : disaster option;
  lose : bool;
  message : string option; (*possible prompt for the user*)
  money : int;
  tuition : int;
  happiness: int;
  time_passed : int;
  grid : square array array
}
(* [init_state j] returns the initial state of the game. *)
val init_state : gamestate


val do' : Command.command -> gamestate -> gamestate
