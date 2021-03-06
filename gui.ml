(* We found the tutorial at the following website helpful for our
 * implementation of the GUI in LablGTK2.
 * http://web.archive.org/web/20160808035304/http://plus.kaist.ac.kr:80/~shoh/
 * ocaml/lablgtk2/lablgtk2-tutorial/*)

open StdLabels
open GMain
open Gtk
open GToolbox
open GBin
open State
open Json

(* [initstate] generates the initial state for the GUI. *)
let initstate = ref (match State.init_from_file "map.txt" with
    | Some m -> m
    | None -> State.init_state 25)

let _ = GtkMain.Main.init ()

(* Initialization for callback actions for upper toolbar *)
let dorm_pressed = ref true
let dining_pressed = ref false
let lecture_pressed = ref false
let power_pressed = ref false
let park_pressed = ref false
let road_pressed = ref false
let pline_pressed = ref false
let bulldoze_pressed = ref false

(* [paused] is used for TimeStep. *)
let paused = ref false
let file_name = ref ""
let refresh = ref false

(* [tuition] handles tuition updates set by the user. *)
let tuition = ref ((!initstate).tuition)

(* Messages for game introduction and instructions *)
let welcome_mess = "Welcome to NOT SIM CITY, an open-ended University Simulator
based on real-life experience at Cornell University!"
let about_message = "Not Sim City: CS 3110 Final Project

KEY FEATURES:
- Map: square grid on which to build
- Dorms: The population-carrying buildings. Will not attract students unless
connected to all resources.
- Resources: Lecture hall, dining hall, and power plant.
- Connectors: Power lines form connections to the power plant. Roads form
connections to lecture and dining halls.

IMPORTANT NUMBERS:
- Funds: the money you have left. If this drops below 0 after the first year,
 you lose.
- Population: the number of students attending your university. If this drops
to 0 after the first year, you lose.
- Happiness: a measurement of how content your students are. This affects
the rate at which students enroll in, or drop out of, your university.

HAPPINESS:
- Building parks increases student happiness.
- Building over forests decreases student happiness.
- Natural disasters decrease student happines. There is a small chance every
month of a natural disaster occurring.
- Decreasing tuition increases happiness, and increasing tuition
does the opposite.

FUNDS:
- Each student pays tuition at the beginning of each year.
- Each building requires upkeep at the beginning of each month.
- Building and destroying buildings costs money."

module type GridSpec = sig
  type t
  val get : t -> x:int -> y:int -> State.building_type
  val set : t -> x:int -> y:int -> terrain:State.terrain -> building:State.building_type -> unit
end


module Grid (Spec : GridSpec) = struct
  open Spec

  (* [action board x y building] returns [false] if there is already a building
   * at (x,y), or sets (x,y) to have the pixmap associated with [building] and
   * returns [true] *)
  let action board ~x ~y ~terrain ~building =
  if (!refresh) then begin
    set board ~x ~y ~terrain ~building ; true end
  else if get board ~x ~y <> Empty  && !bulldoze_pressed = false then false
  else begin
      set board ~x ~y ~terrain ~building ; true
    end
end


(* Makes new window with title "Not Sim City" *)
let window = GWindow.window ~title:"Not Sim City" ~position:`CENTER ~width:800 ~height:800 ~resizable:true ()


(* Creates pixmaps of building images *)
let pixnone =
  GDraw.pixmap ~window ~width:20 ~height:20 ~mask:true ()
let pixwater =
  GDraw.pixmap_from_xpm ~file:"water.xpm" ()
let pixclear =
  GDraw.pixmap_from_xpm ~file:"clear.xpm" ()
let pixforest =
  GDraw.pixmap_from_xpm ~file:"forest.xpm" ()

let pixdorm =
  GDraw.pixmap_from_xpm ~file:"dorm.xpm" ()
let pixdining =
  GDraw.pixmap_from_xpm ~file:"dining.xpm" ()
let pixlecture =
  GDraw.pixmap_from_xpm ~file: "lecture.xpm" ()
let pixpower =
  GDraw.pixmap_from_xpm ~file: "power.xpm" ()
let pixpark =
  GDraw.pixmap_from_xpm ~file: "park.xpm" ()
let pixroad =
  GDraw.pixmap_from_xpm ~file: "road.xpm" ()
let pixpline =
  GDraw.pixmap_from_xpm ~file: "pline.xpm" ()

(* Create a new hbox with an image packed into it
 * and pack the box *)
let xpm_label_box ~file ~text ~packing () =
  if not (Sys.file_exists file) then failwith (file ^ " does not exist");

(* Create box for image and pack *)
let box = GPack.hbox ~border_width:2 ~packing () in

(* Make pixmap from file, put pixmap in box *)
let pixmap = GDraw.pixmap_from_xpm ~file () in
GMisc.pixmap pixmap ~packing:(box#pack ~padding:3) ();
GMisc.label ~text ~packing:(box#pack ~padding:3) ()

(* [cell] is a button with a pixmap on it. *)
class cell ~build ~terrain ?packing ?show () =

  (* Sets up tooltips for cell *)
  let tooltips = GData.tooltips () in
  let button = GButton.button ?packing ?show ~relief:`NONE () in
  let _ = tooltips#set_tip button#coerce
      ~text:(begin match build with
        | Empty -> begin match terrain with
            | Clear -> "Clear"
            | Forest -> "Forest"
            | Water -> "Water" end
        | _ -> "Delete cost: $" ^
               string_of_int (State.get_dcost build) end) in
  (* Associates pixmap with building *)
  let bldimg = match build with
    | Empty -> begin match terrain with
        | Clear -> pixclear
        | Forest -> pixforest
        | Water -> pixwater end
    | Dorm -> pixdorm
    | Dining -> pixdining
    | Lecture -> pixlecture
    | Power -> pixpower
    | Park -> pixpark
    | Road -> pixroad
    | Pline -> pixpline
    | _ -> pixdining in

  (* [cell] object *)
  object (self)
    inherit GObj.widget button#as_widget
    method connect = button#connect
    val mutable building : State.building_type = Empty
    val pm = GMisc.pixmap bldimg ~packing:button#add ()
    method building = building
    method terrain = terrain
    (* Updates cell building *)
    method set_bld bld terr =
      if bld <> building then begin
        building <- bld;
        pm#set_pixmap
          (match bld with
           | Dorm -> pixdorm
           | Dining -> pixdining
           | Lecture -> pixlecture
           | Power -> pixpower
           | Park -> pixpark
           | Road -> pixroad
           | Pline -> pixpline
           | Empty -> begin match terr with
               | Clear -> pixclear
               | Forest -> pixforest
               | Water -> pixwater end
           | _ -> pixdining);
        (* Updates tooltip *)
        tooltips#set_tip button#coerce
          ~text:(begin
              match building with
                  | Empty -> begin match terr with
                      | Clear -> "Clear"
                      | Forest -> "Forest"
                      | Water -> "Water" end
                  | _ -> "Delete cost: $" ^
                         string_of_int (State.get_dcost building)
            end)
      end
  end


module GameGrid = Grid (
  struct
    type t = cell array array
    let get (grid : t) ~x ~y = grid.(x).(y)#building
    let set (grid : t) ~x ~y ~terrain ~building = grid.(x).(y)#set_bld building terrain
  end
  )


(* Conducts a game *)
open GameGrid

class game ~(frame : #GContainer.container) ~(poplabel : #GMisc.label)
    ~(fundslabel : #GMisc.label) ~(happlabel : #GMisc.label)
    ~(statusbar : #GMisc.statusbar) ~(losebar : #GMisc.statusbar) =

  let size = ref (Array.length (!initstate.grid)) in

  let table = GPack.table ~columns:!size ~rows:!size ~packing:(frame#add_with_viewport) () in

  object (self)
    val mutable cells =
      Array.init !size
        ~f:(fun i -> Array.init !size
               ~f:(fun j ->
                   let t = (Array.get (Array.get !initstate.grid i) j).terrain in
                   let b = (Array.get (Array.get !initstate.grid i) j).btype in
                   new cell ~build:b ~terrain:t ~packing:(table#attach ~top:i ~left:j) ()))

    (* Used for information displayed in bottom bar *)
    val poplabel = poplabel
    val happlabel = happlabel
    val fundslabel = fundslabel

    (* Message normally displayed in statusbar *)
    val turn = statusbar#new_context ~name:"turn"

    (* Message that flashes in statusbar *)
    val messages = statusbar#new_context ~name:"messages"

    (* Messages displayed in losebar *)
    val losestatus = losebar#new_context ~name:"lose_status"
    val dis_messages = losebar#new_context ~name:"dis_message"

    method grid = cells
    method table = table
    val mutable current_building = Dorm

    (* [refresh_cells] regenerates the grid. *)
    method refresh_cells () =
      size := (Array.length !initstate.grid);
      cells <- Array.init !size
          ~f:(fun i -> Array.init !size
                 ~f:(fun j ->
                     let t = (Array.get (Array.get !initstate.grid i) j).terrain in
                     let b = (Array.get (Array.get !initstate.grid i) j).btype in
                     new cell ~build:b ~terrain:t ~packing:(table#attach ~top:i ~left:j) ()));
      for i = 0 to !size-1 do
        for j = 0 to !size-1 do
          let cell = cells.(i).(j) in
          cell#connect#enter ~callback:cell#misc#grab_focus; (* when hovering *)
          cell#connect#clicked ~callback:(fun () -> self#play i j);
          let t = (Array.get (Array.get !initstate.grid i) j).terrain in
          let b = (Array.get (Array.get !initstate.grid i) j).btype in
          let bld = match b with
            | Section (x,y) -> (Array.get (Array.get !initstate.grid x) y).btype
            | _ -> b in
          action cells i j t bld
        done done

    (* [make_message] generates a message from the current state if a message
     * exists. *)
    method make_message =
      match !initstate.message with
      | Some m -> GToolbox.message_box ~title:"Message" m
      | None -> ()

    (* [update_happlabel] updates the text for the happiness label on the
     * bottom toolbar. *)
    method update_happlabel () =
      let newhapp = string_of_int (!initstate.happiness) in
      happlabel#set_text (Printf.sprintf "Happiness: "^newhapp)

    (* [update_poplabel] updates the text for the population label on the
     * bottom toolbar. *)
    method update_poplabel () =
      let p = (State.get_num !initstate.grid State.get_rpop) in
      poplabel#set_text (Printf.sprintf "Population: %d students" p)

    (* [update_fundslabel] updates the text for the funds label on the
     * bottom toolbar. *)
    method update_fundslabel () =
      let f = !initstate.money in
      fundslabel#set_text (Printf.sprintf "Funds: $%d" f)

    (* [update_build] updates the [current_building] based on which button on
     * the upper toolbar was last pressed. *)
    method update_build () =
      current_building <- if !dorm_pressed then Dorm
        else if !lecture_pressed then Lecture
        else if !dining_pressed then Dining
        else if !power_pressed then Power
        else if !park_pressed then Park
        else if !road_pressed then Road
        else if !pline_pressed then Pline
        else if !bulldoze_pressed then Empty
        else Empty

    (* [time_step] updates [state] by taking a TimeStep. *)
    method time_step =
      if !refresh then (self#refresh_cells (); refresh := false) else
      if not !paused then (
        initstate := do' TimeStep !initstate;
        turn#pop ();
        turn#push (get_time_passed !initstate);
        let m = match !initstate.message with
          | None -> "University is up and running"
          | Some mess -> mess
        in
        if !initstate.lose then losestatus#pop (); losestatus#push m;
        if !initstate.disaster <> None then
           dis_messages#flash m;
        self#update_happlabel ();
        self#update_poplabel ();
        self#update_fundslabel ())

    method start_time : unit Async_kernel.Deferred.t = Async.(
      after (Core.sec 5.) >>= fun _ ->
      self#time_step;
      if !initstate.lose
      then return ()
      else self#start_time )

    method updatestate x y : bool =
      try (self#update_build (); initstate := match current_building with
          | Empty -> State.do' (Delete (x,y)) !initstate
          | Dorm -> State.do' (Build (x,y,Dorm)) !initstate
          | Dining -> State.do' (Build (x,y,Dining)) !initstate
          | Lecture -> State.do' (Build (x,y,Lecture)) !initstate
          | Power -> State.do' (Build (x,y,Power)) !initstate
          | Park -> State.do' (Build (x,y,Park)) !initstate
          | Road -> State.do' (Build (x,y,Road)) !initstate
          | Pline -> State.do' (Build (x,y,Pline)) !initstate
          | _ -> !initstate); true
      with
      | _ -> false

    method btostring btype =
      match btype with
      | Empty -> "empty"
      | Dorm -> "dorm"
      | Lecture -> "lecture"
      | Power -> "power"
      | Dining -> "dining"
      | Park -> "park"
      | Road -> "road"
      | Pline -> "pline"
      | Section (x,y) -> "section"

    method play x y =
      if self#updatestate x y then
        (self#update_poplabel (); self#update_happlabel ();
         self#update_fundslabel ();
         if !initstate.lose then
           (* Generates popup button for losing *)
           let loselist = ["Ok"; "Quit"] in
           let lose_popup = GToolbox.question_box ~title:"YOU LOST"
               ~buttons:loselist "You Lost." in
           let next_lose_action b =
             match b with
             | 1 -> ()                (* Closes popup *)
             | 2 -> Main.quit () in   (* Quits game *)
           next_lose_action lose_popup
         else
           (* Generate message from current state *)
           self#make_message;
         for i = max (x-2) 0 to min (x+2) (!size-1) do
           for j = max (y-2) 0 to min (y+2) (!size-1) do
             let t = (Array.get (Array.get !initstate.grid i) j).terrain in
             let b = (Array.get (Array.get !initstate.grid i) j).btype in
             let bld = match b with
               | Section (x,y) -> (Array.get (Array.get !initstate.grid x) y).btype
               | _ -> b in
             action cells i j t bld
           done done)

    initializer
      for i = 0 to !size-1 do
        for j = 0 to !size-1 do
          let cell = cells.(i).(j) in
          cell#connect#enter ~callback:cell#misc#grab_focus; (* when hovering *)
          cell#connect#clicked ~callback:(fun () -> self#play i j) (* when clicked, execute [play i j]*)
        done done;

      losestatus#push "University is up and running";
      self#start_time;
      self#update_poplabel ();
      self#update_happlabel ();
      self#update_fundslabel ();
      turn#push (get_time_passed !initstate);
      Async.(Thread.create Scheduler.go ());
      ()
  end


(* Other graphics *)

let vbox = GPack.vbox ~packing:window#add ()

(* Top click-down menu bar *)
let ui_info = "<ui>\
               <menubar name='MenuBar'>\
               <menu action='FileMenu'>\
               <menuitem action='New'/>\
               <menuitem action='Open'/>\
               <menuitem action='Save'/>\
               <menuitem action='SaveAs'/>\
               <separator/>\
               <menuitem action='Quit'/>\
               </menu>\
               <menu action='PreferencesMenu'>\
               <menuitem action='Pause'/>\
               </menu>\
               <menu action='HelpMenu'>\
               <menuitem action='About'/>\
               </menu>\
               </menubar>\
               </ui>"

(* [activ_action ac] is the result of clicking [ac]. *)
let activ_action ac =
  flush stdout;
  let ac_name = ac#name in
  let rec exec = function
  | "New" -> exec "Load"
  | "About" -> GToolbox.message_box ~title:"About" about_message
  | "Pause" -> paused := not !paused
  | "Save" -> (if !file_name <> "" then begin
  if Json.save_state !file_name !initstate
    then GToolbox.message_box ~title:"Save" "Save successful!"
    else GToolbox.message_box ~title:"Save" "Failed to save"
  end
     else (exec "SaveAs"))
  | "SaveAs" -> let save = GToolbox.select_file ~title:"Save" () in
    ( match save with
      | Some n -> if Json.save_state n !initstate
        then (file_name := n; GToolbox.message_box ~title:"Save" "Save successful!")
        else GToolbox.message_box ~title:"Save" "Failed to save"
      | None -> GToolbox.message_box ~title:"Save" "Failed to save" )
  | "Open" -> let openf = GToolbox.select_file ~title:"Open" () in
    ( match openf with
      | Some n -> begin match (Json.load_state n) with
          | Some s -> (initstate := s; refresh := true;
                       GToolbox.message_box ~title:"Open"
                         "Load successful! Please wait while the map refreshes.")
        | None -> GToolbox.message_box ~title:"Open" "Failed to open" end
      | None -> GToolbox.message_box ~title:"Open" "Failed to open" )
  | "Quit" -> window#destroy ()
  | _ -> ()
  in exec ac_name

let setup_ui window =
  let a = GAction.add_action in
  let ta = GAction.add_toggle_action in
  let radio = GAction.group_radio_actions in
  let ra = GAction.add_radio_action in

  let actions = GAction.action_group ~name:"Actions" () in
  GAction.add_actions actions
    [ a "FileMenu" ~label:"_File" ;
      a "PreferencesMenu" ~label:"_Preferences" ;
      a "DisasterMenu" ~label:"_Disaster" ;
      a "HelpMenu" ~label:"_Help" ;

      (* Menu Items: First string: Action name corresponding to [ui_info]
       * [stock]: prebuilt common menu/toolbar items and corresponding icons
       * [callback]: what happens when button is clicked
       * [accel]: keyboard shortcut *)
      a "New" ~stock:`NEW ~tooltip:"Create a new file"
        ~callback:activ_action ;
      a "Open" ~stock:`OPEN ~tooltip:"Open a file"
        ~callback:activ_action ;
      a "Save" ~stock:`SAVE ~tooltip:"Save current file"
        ~callback:activ_action ;
      a "SaveAs" ~stock:`SAVE_AS
        ~tooltip:"Save to a file" ~callback:activ_action ;
      a "Quit" ~stock:`QUIT ~tooltip:"Quit"
        ~callback:activ_action;
      a "About" ~label:"_About" ~accel:"<control>A" ~tooltip:"About"
        ~callback:activ_action ;

      ta "Pause" ~label:"_Pause"
        ~accel:"<control>P"
        ~callback:activ_action ~active:false ;
    ] ;

  (* [ui_m] constructs the user interface from [ui_info] and actions *)
  let ui_m = GAction.ui_manager () in
  ui_m#insert_action_group actions 0 ;
  window#add_accel_group ui_m#get_accel_group ;
  ui_m#add_ui_from_string ui_info ;

  (* [box1] contains the top menu bar, and is contained in vbox. *)
  let box1 = GPack.vbox ~packing:vbox#pack () in
  box1#pack (ui_m#get_widget "/MenuBar") ;

  (* [h_box1] sets up the box containing the Dorm, Dining, Lecture, and
   * Power Source buttons. *)
  let h_box1 = GPack.hbox ~packing:box1#pack ~height:50 () in

  (* [h_box2] sets up the box containing the Park, Road, Power Line, and
   * Bulldoze buttons. *)
  let h_box2 = GPack.hbox ~packing:box1#pack  ~height:50 () in

  (* [button_text] returns a string with building costs (if applicable)
   * for a button. *)
  let button_text str b =
    str ^ ": $" ^ string_of_int (State.get_bcost b) in

  (* [dorm_button] creates a button with the xpm_image and puts it in h_box1. *)
  let dorm_button = GButton.button ~packing:h_box1#add () in
  (* Connects the click to callback *)
  dorm_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := true; dining_pressed := false;
      lecture_pressed := false; power_pressed := false;
      park_pressed := false; road_pressed := false;
      pline_pressed := false; bulldoze_pressed := false);
  (* Creates box with xpm image and put into button *)
  xpm_label_box ~file:"dorm.xpm" ~text:(button_text "Dorm" Dorm)
    ~packing:dorm_button#add ();

  (* [dining_button] creates a button with the xpm_image and puts it in
   * h_box1. *)
  let dining_button = GButton.button ~packing:h_box1#add () in
  dining_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := true;
      lecture_pressed := false; power_pressed := false;
      park_pressed := false; road_pressed := false;
      pline_pressed := false; bulldoze_pressed := false);
  xpm_label_box ~file:"dining.xpm" ~text:(button_text "Dining Hall" Dining)
    ~packing:dining_button#add ();

  (* [lecture_button] creates a button with the xpm_image and puts it in
   * h_box1. *)
  let lecture_button = GButton.button ~packing:h_box1#add () in
  lecture_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := false;
      lecture_pressed := true; power_pressed := false;
      park_pressed := false; road_pressed := false;
      pline_pressed := false; bulldoze_pressed := false);
  xpm_label_box ~file:"lecture.xpm" ~text:(button_text "Lecture Hall" Lecture)
    ~packing:lecture_button#add ();

  (* [power_button] creates a button with the xpm_image and puts it in
   * h_box1. *)
  let power_button = GButton.button ~packing:h_box1#add () in
  power_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := false;
      lecture_pressed := false; power_pressed := true;
      park_pressed := false; road_pressed := false;
      pline_pressed := false; bulldoze_pressed := false);
  xpm_label_box ~file:"power.xpm" ~text:(button_text "Power Source" Power)
    ~packing:power_button#add ();

  (* [park_button] creates a button with the xpm_image and puts it in h_box2. *)
  let park_button = GButton.button ~packing:h_box2#add () in
  park_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := false;
      lecture_pressed := false; power_pressed := false;
      park_pressed := true; road_pressed := false;
      pline_pressed := false; bulldoze_pressed := false);
  xpm_label_box ~file:"park.xpm" ~text:(button_text "Park" Park)
    ~packing:park_button#add ();

  (* [road_button] creates a button with the xpm_image and puts it in h_box2. *)
  let road_button = GButton.button ~packing:h_box2#add () in
  road_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := false;
      lecture_pressed := false; power_pressed := false;
      park_pressed := false; road_pressed := true;
      pline_pressed := false; bulldoze_pressed := false);
  xpm_label_box ~file:"road.xpm" ~text:(button_text "Road" Road)
    ~packing:road_button#add ();

  (* [pline_button] creates a button with the xpm_image and puts it in
   * h_box2. *)
  let pline_button = GButton.button ~packing:h_box2#add () in
  pline_button#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := false;
      lecture_pressed := false; power_pressed := false;
      park_pressed := false; road_pressed := false;
      pline_pressed := true; bulldoze_pressed := false);
  xpm_label_box ~file:"pline.xpm" ~text:(button_text "Power Line" Pline)
    ~packing:pline_button#add ();

  (* [bulldoze] creates a button with the xpm_image and puts it in h_box2. *)
  let bulldoze = GButton.button ~packing:h_box2#add () in
  bulldoze#connect#clicked ~callback:
    (fun () -> dorm_pressed := false; dining_pressed := false;
      lecture_pressed := false; power_pressed := false;
      park_pressed := false; road_pressed := false;
      pline_pressed := false; bulldoze_pressed := true);
  xpm_label_box ~file:"bulldozer.xpm" ~text:"Bulldozer" ~packing:bulldoze#add ();

  (* Horizontal line between top menu bar and grid *)
  GMisc.separator `HORIZONTAL ~packing:box1#pack () ;

  (* Frame for game *)
  let frame = GBin.scrolled_window ~border_width:10
      ~hpolicy:`AUTOMATIC ~vpolicy:`AUTOMATIC ~packing:vbox#add () in

  (* Box for status and lose bars at the bottom of [window] *)
  let hbox_time = GPack.hbox ~packing:vbox#pack () in
  let hbox = GPack.hbox ~packing:vbox#pack () in

  (* Sets up status bar that displays turn and messages *)
  let bar = GMisc.statusbar ~packing:hbox#add ~width:100 () in
  let framepop = GBin.frame ~shadow_type:`IN ~packing:hbox#add () in
  let framefunds = GBin.frame ~shadow_type:`IN ~packing:hbox#pack () in
  let framehapp = GBin.frame ~shadow_type:`IN ~packing:hbox#add () in

  (* Labels on bottom bar that display population, money, and happiness *)
  let pop = GMisc.label ~justify:`LEFT ~xpad:5 ~xalign:0.0
      ~packing:framepop#add () in
  let funds = GMisc.label ~justify:`LEFT ~xpad:5 ~xalign:0.0
      ~packing:framefunds#add () in
  let happ = GMisc.label ~justify:`LEFT ~xpad:5 ~xalign:0.0
      ~packing:framehapp#add () in

  (* Sets up losebar at the bottom of [window] *)
  let losebar = GMisc.statusbar ~packing:hbox_time#add ~height:30
      ~has_resize_grip:false () in

  (* [tuition_window] is a window that pops up once the user_tuition button
   * ("Change Tuition") is clicked. *)
  let add_tuition () = (
    let tuition_window = GWindow.window ~title:"Set Tuition"
        ~position:`CENTER ~border_width:0 () in
      tuition_window#connect#destroy ~callback:tuition_window#destroy;

    (* [tbox1] sets up a vbox in [tuition_window]. *)
    let tbox1 = GPack.vbox ~packing:tuition_window#add () in

    (* [tbox2] sets up a vbox in [tbox1] for the radio buttons. *)
    let tbox2 = GPack.vbox ~spacing:10 ~border_width:50 ~packing:tbox1#add () in

    (* The following buttons implement the different button options in
     * [tuition_window]; they are put in [tbox2]. *)
    let button_zero = GButton.radio_button ~label:"$0" ~active:(!tuition=0)
        ~packing:tbox2#add () in
    let button_ten = GButton.radio_button ~group:button_zero#group
        ~label:"$10000" ~active:(!tuition=10000) ~packing:tbox2#add () in
    let button_twenty = GButton.radio_button ~group:button_zero#group
        ~label:"$20000" ~active:(!tuition=20000) ~packing:tbox2#add () in
    let button_thirty = GButton.radio_button ~group:button_zero#group
        ~label:"$30000" ~active:(!tuition=30000) ~packing:tbox2#add () in
    let button_forty = GButton.radio_button ~group:button_zero#group
        ~label:"$40000" ~active:(!tuition=40000) ~packing:tbox2#add () in
    let button_fifty = GButton.radio_button ~group:button_zero#group
        ~label:"$50000" ~active:(!tuition=50000) ~packing:tbox2#add () in
    let button_sixty = GButton.radio_button ~group:button_zero#group
        ~label:"$60000" ~active:(!tuition=60000) ~packing:tbox2#add () in
    let button_seventy = GButton.radio_button ~group:button_zero#group
        ~label:"$70000" ~active:(!tuition=70000) ~packing:tbox2#add () in
    let button_eighty = GButton.radio_button ~group:button_zero#group
        ~label:"$80000" ~active:(!tuition=80000) ~packing:tbox2#add () in
    let button_ninety = GButton.radio_button ~group:button_zero#group
        ~label:"$90000" ~active:(!tuition=90000) ~packing:tbox2#add () in
    let button_hundred = GButton.radio_button ~group:button_zero#group
        ~label:"$100000" ~active:(!tuition=100000) ~packing:tbox2#add () in

    (* Creates line between [tbox2] for the radio buttons and [tbox3] that
     * holds the [submit_button]. *)
    let separator = GMisc.separator `HORIZONTAL ~packing: tbox1#pack () in

    (* [tbox3] is a vbox that holds [submit_button]. *)
    let tbox3 = GPack.vbox ~spacing:10 ~border_width:10 ~packing:tbox1#pack () in

    (* [set_tuition] sets [tuition] resulting from the final button choice
     * clicked in [tuition_window]. *)
    let set_tuition () =
      tuition := (if button_zero#active then 0
        else if button_ten#active then 10000
        else if button_twenty#active then 20000
        else if button_thirty#active then 30000
        else if button_forty#active then 40000
        else if button_fifty#active then 50000
        else if button_sixty#active then 60000
        else if button_seventy#active then 70000
        else if button_eighty#active then 80000
        else if button_ninety#active then 90000
        else if button_hundred#active then 100000
        else !tuition)
    in

    (* [submit_button] in tbox3 closes [tuition_window] when clicked. *)
    let submit_button = GButton.button ~label:"Submit" ~packing:tbox3#add () in
    submit_button#connect#clicked
      ~callback:(fun () -> set_tuition (); tuition_window#destroy ());

    (* Shows tuition window in GUI. *)
    tuition_window#show ()) in

  (* [user_tuition] is the ("Change Tuition") button at the bottom toolbar that
   * opens [tuition_window] when clicked. *)
  let user_tuition = GButton.button ~label:"Change Tuition" ~packing:hbox#add () in
  user_tuition#connect#clicked
    ~callback: (fun () -> add_tuition ());

  (* [buttonslist] is the text for the different buttons for [beginbox]. *)
  let buttonslist = ["Instructions";"Map from file";"Map from size"] in

  (* [sizelist] is the text for the different size option buttons. *)
  let sizelist = ["20x20";"30x30";"40x40"] in

  (* [beginbox] is the first question box that appears in the GUI that
   * welcomes users to the game by providing instructions, opening a text file,
   * or letting users choose from a pre-generated text file size. *)
  let beginbox = GToolbox.question_box ~title:"Welcome!"
      ~buttons:buttonslist welcome_mess in

  (* [nextbutton] generates the next button based on [b]. *)
  let rec nextbutton b = match b with
    | 1 -> (* Lists instructions and re-displays [beginbox] choices *)
      let abt = GToolbox.question_box ~title:"Instructions"
               ~buttons:buttonslist about_message in
      nextbutton abt
    | 2 -> (* Enables user to import a valid text file map. Starts game with
            * a default map if chosen text file is not a valid map. *)
      (let t = GToolbox.select_file ~title:"Select File" () in
            match t with
            | Some m -> (initstate := match (State.init_from_file m) with
                | Some st -> st
                | None ->
                  GToolbox.message_box ~title:"Select File"
                    "Cannot load map from file - using default map";
                  !initstate)
            | None ->  GToolbox.message_box ~title:"Select File"
                         "No file selected - using default map")
    | 3 -> (* Enables user to choose the size of a default map based on sizes
            * provided in [sizelist]. *)
      (let numbox = GToolbox.question_box ~title:"Choose Size"
           ~buttons:sizelist "Choose your map size" in
       match numbox with
       | 1 -> (initstate :=
          match (State.init_from_file "default20.txt") with
           | Some st -> st
           | None -> GToolbox.message_box ~title:"Choose Size"
                       "Cannot access 20x20 map - using default map";
             !initstate)
       | 2 -> (initstate := match State.init_from_file "default30.txt" with
           | Some st -> st
           | None -> GToolbox.message_box ~title:"Choose Size"
                       "Cannot access 30x30 map - using default map";
             !initstate)
       | 3 -> (initstate := match State.init_from_file "default40.txt" with
           | Some st -> st
           | None -> GToolbox.message_box ~title:"Choose Size"
                       "Cannot access 40x40 map - using default map";
             !initstate))
  in nextbutton beginbox;

  (* Creates new game *)
  new game ~frame ~poplabel:pop ~fundslabel:funds ~happlabel:happ
    ~statusbar:bar ~losebar:losebar

(* Runs the GUI. *)
let _ =
  window#connect#destroy ~callback:Main.quit;
  setup_ui window ;
  window#show ();
  Main.main ()
