
open Lwt
open Cohttp
open Yojson
open XHRClient

open Game

(* Yojson aliases *)

(* [from_string] is Yojson.Basic.from_string *)
let from_string = Yojson.Basic.from_string
(* [to_string_case] is Yojson.Basic.Util.to_string *)
let to_string = Yojson.Basic.Util.to_string
(* [member] is Yojson.Basic.Util.member *)
let member = Yojson.Basic.Util.member
(* [to_list] is Yojson.Basic.Util.to_list *)
let to_list = Yojson.Basic.Util.to_list
(* [to_int] is Yojson.Basic.Util.to_int *)
let to_int = Yojson.Basic.Util.to_int

(* [baseURL] is the base URL to request to (currently in relative path mode) *)
let baseURL = ""

(* [api_key] is the API key for this client to access the server *)
let api_key = ref ""

(* [event_source_constructor] is a function to construct event sources *)
let event_source_constructor = Js.Unsafe.global##_EventSource

(* [event_sources] is a list event sources *)
let event_sources = ref []

(* [headers] is the default headers for JSON requests *)
let headers = Header.init_with "content-type" "application/json"

(* [result] contains the resulting value from a request with possible errors *)
type 'a result = Val of 'a 
                 | Exists of string
                 | Not_found of string 
                 | Full of string 
                 | Failed of string
                 | Server_error of string
                 | Success

(* [local_storage] is the localStorage javascript object *)
let local_storage = 
  match (Js.Optdef.to_option Dom_html.window##localStorage) with
  | Some value -> value
  | None -> assert false

(* [server_error_msg] is the message corresponding to server errors *)
let server_error_msg =
  "Something went wrong. Please ensure that the server is running properly."

(* [fail] is a failure callback *)
let fail = fun _ -> assert false

let init_auth () = 
  let key = 
    Js.Opt.get (local_storage##getItem (Js.string "key")) fail |> Js.to_string
  in
  local_storage##removeItem (Js.string "key");
  api_key := key

let join_game player_name game_name = 
  {
    headers;
    meth = `POST;
    url = baseURL ^ "/api/game";
    req_body = "{\"playerName\":\"" ^ player_name ^ "\", \"gameName\":\"" ^ 
                game_name ^ "\"}"
  }
  |> XHRClient.exec
  >>= fun res -> 
      begin
        (
        match res.status with
        | `OK -> 
            begin
              let json = Yojson.Basic.from_string res.res_body in
              let key = json |> member "key" |> to_string in
              local_storage##setItem (Js.string "key",Js.string key);
              Val (state_from_json (json |> member "game"))
            end
        | `Not_found -> Not_found res.res_body
        | `Bad_request -> Full res.res_body
        | `Not_acceptable -> Exists res.res_body
        | _ -> Server_error server_error_msg
        )
        |> Lwt.return
      end

let create_game player_name game_name = 
  {
    headers;
    meth = `PUT;
    url = baseURL ^ "/api/game";
    req_body = "{\"playerName\":\"" ^ player_name ^ "\", \"gameName\":\"" ^ 
                game_name ^ "\"}"
  }
  |> XHRClient.exec
  >>= fun res -> 
      begin
        (
        match res.status with
        | `OK -> 
            begin
              let json = Yojson.Basic.from_string res.res_body in
              let key =  json |> member "key" |> to_string in
              local_storage##setItem (Js.string "key",Js.string key);
              Val (state_from_json (json |> member "game"))
            end
        | `Bad_request -> Exists res.res_body
        | _ -> Server_error server_error_msg
        )
        |> Lwt.return
      end

let leave_game player_name game_name = 
  {
    headers;
    meth = `DELETE;
    url = baseURL ^ "/api/game";
    req_body = "{\"key\": \"" ^ !api_key ^ "\", \"playerName\":\"" ^ 
                player_name ^ "\", \"gameName\":\"" ^ game_name ^ "\"}"
  }
  |> XHRClient.exec_sync
  |> ignore

let execute_move game_name move = 
  {
    headers;
    meth = `POST;
    url = baseURL ^ "/api/move";
    req_body = "{\"key\": \"" ^ !api_key ^ "\",\"gameName\":\"" ^ game_name ^ 
               "\", \"move\":" ^ Game.move_to_json move ^ "}"
  }
  |> XHRClient.exec
  >>= fun res ->
      begin
        (
        match res.status with
        | `OK -> Success
        | `Bad_request -> Failed res.res_body
        | _ -> Server_error server_error_msg
        )
        |> Lwt.return
      end

(* [subscribe endpoint player_name game_name callback] subscribes a callback for
 * a player with name [player_name] an event source of the game with name 
 * [game_name] associated with an endpoint
 *)
let subscribe endpoint player_name game_name callback = 
  let base = Uri.of_string (baseURL ^ "/api/" ^ endpoint) in
  let url = 
    Uri.with_query base 
    [("gameName",[game_name]); ("playerName",[player_name]); ("key",[!api_key])]
    |> Uri.to_string
  in
  let event_source = jsnew event_source_constructor (Js.string url) in
  event_sources := event_source::!event_sources;
  event_source##onmessage <- Js.wrap_callback (fun event ->
    event##data
    |> Js.to_string
    |> Yojson.Basic.from_string
    |> callback
  );
  event_source##onerror <- Js.wrap_callback (fun event -> 
    event_source##close ()
  )

let subscribe_updates = 
  subscribe "game"

let send_message player_name game_name msg = 
  {
    headers;
    meth = `POST;
    url = baseURL ^ "/api/messaging";
    req_body = "{\"key\":\"" ^ !api_key ^ "\",\"playerName\":\"" ^ player_name ^
               "\",\"gameName\":\"" ^ game_name ^ "\", \"msg\":\"" ^ msg ^ "\"}"
  }
  |> XHRClient.exec
  |> ignore

let subscribe_messaging = 
  subscribe "messaging"

let close_sources () = 
  List.iter (fun event_source -> event_source##close ()) !event_sources
