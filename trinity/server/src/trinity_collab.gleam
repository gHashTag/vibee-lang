// TRINITY Collaboration Server v22.φ
// WebSocket server for real-time collaboration
// Built with Gleam on BEAM (Erlang VM)
//
// φ² + 1/φ² = 3

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/option.{type Option, None, Some}
import gleam/dict.{type Dict}
import gleam/list
import gleam/int
import gleam/float
import gleam/string
import gleam/json.{type Json}
import gleam/dynamic.{type Dynamic}
import gleam/result
import gleam/io
import mist
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/bytes_builder
import glisten/websocket.{type WebsocketMessage, Text, Binary}

// ═══════════════════════════════════════════════════════════════════════════════
// φ CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const phi: Float = 1.618033988749895
const phi_sq: Float = 2.618033988749895
const phi_inv: Float = 0.618033988749895

/// Validate Golden Identity: φ² + 1/φ² = 3
pub fn validate_golden_identity() -> Bool {
  let result = phi_sq +. 1.0 /. phi_sq
  float.absolute_value(result -. 3.0) <. 0.0000000001
}

// ═══════════════════════════════════════════════════════════════════════════════
// CRDT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// CRDT Counter - Conflict-free replicated counter
pub type CrdtCounter {
  CrdtCounter(
    increments: Dict(String, Int),
    decrements: Dict(String, Int),
  )
}

/// Create new CRDT counter
pub fn new_counter() -> CrdtCounter {
  CrdtCounter(increments: dict.new(), decrements: dict.new())
}

/// Increment counter for node
pub fn counter_increment(counter: CrdtCounter, node_id: String) -> CrdtCounter {
  let current = dict.get(counter.increments, node_id) |> result.unwrap(0)
  CrdtCounter(
    ..counter,
    increments: dict.insert(counter.increments, node_id, current + 1),
  )
}

/// Get counter value
pub fn counter_value(counter: CrdtCounter) -> Int {
  let inc = dict.values(counter.increments) |> list.fold(0, int.add)
  let dec = dict.values(counter.decrements) |> list.fold(0, int.add)
  inc - dec
}

/// Merge two counters
pub fn counter_merge(a: CrdtCounter, b: CrdtCounter) -> CrdtCounter {
  let merge_dicts = fn(d1: Dict(String, Int), d2: Dict(String, Int)) -> Dict(String, Int) {
    dict.fold(d2, d1, fn(acc, key, value) {
      let current = dict.get(acc, key) |> result.unwrap(0)
      dict.insert(acc, key, int.max(current, value))
    })
  }
  
  CrdtCounter(
    increments: merge_dicts(a.increments, b.increments),
    decrements: merge_dicts(a.decrements, b.decrements),
  )
}

/// LWW Register - Last-Writer-Wins register
pub type LwwRegister(a) {
  LwwRegister(value: Option(a), timestamp: Int)
}

/// Create new LWW register
pub fn new_register() -> LwwRegister(a) {
  LwwRegister(value: None, timestamp: 0)
}

/// Set register value
pub fn register_set(register: LwwRegister(a), value: a, timestamp: Int) -> LwwRegister(a) {
  LwwRegister(value: Some(value), timestamp: timestamp)
}

/// Merge two registers (LWW)
pub fn register_merge(a: LwwRegister(t), b: LwwRegister(t)) -> LwwRegister(t) {
  case b.timestamp > a.timestamp {
    True -> b
    False -> a
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOM STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Room state
pub type RoomState {
  RoomState(
    id: String,
    clients: List(String),
    scroll_position: LwwRegister(Int),
    active_section: LwwRegister(String),
    theme: LwwRegister(String),
    view_count: CrdtCounter,
    cursors: Dict(String, #(Float, Float, Int)),
  )
}

/// Create new room
pub fn new_room(id: String) -> RoomState {
  RoomState(
    id: id,
    clients: [],
    scroll_position: new_register(),
    active_section: register_set(new_register(), "hero", 0),
    theme: register_set(new_register(), "dark", 0),
    view_count: new_counter(),
    cursors: dict.new(),
  )
}

/// Add client to room
pub fn room_add_client(room: RoomState, client_id: String) -> RoomState {
  RoomState(..room, clients: [client_id, ..room.clients])
}

/// Remove client from room
pub fn room_remove_client(room: RoomState, client_id: String) -> RoomState {
  RoomState(
    ..room,
    clients: list.filter(room.clients, fn(c) { c != client_id }),
    cursors: dict.delete(room.cursors, client_id),
  )
}

/// Update cursor position
pub fn room_update_cursor(
  room: RoomState,
  client_id: String,
  x: Float,
  y: Float,
  timestamp: Int,
) -> RoomState {
  RoomState(
    ..room,
    cursors: dict.insert(room.cursors, client_id, #(x, y, timestamp)),
  )
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVER STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Server message types
pub type ServerMessage {
  ClientJoin(room_id: String, client_id: String, reply: Subject(RoomState))
  ClientLeave(room_id: String, client_id: String)
  UpdateState(room_id: String, client_id: String, update: StateUpdate)
  UpdateCursor(room_id: String, client_id: String, x: Float, y: Float)
  GetRoom(room_id: String, reply: Subject(Option(RoomState)))
  GetStats(reply: Subject(ServerStats))
}

/// State update types
pub type StateUpdate {
  ScrollUpdate(value: Int, timestamp: Int)
  SectionUpdate(value: String, timestamp: Int)
  ThemeUpdate(value: String, timestamp: Int)
  ViewCountIncrement(node_id: String)
}

/// Server statistics
pub type ServerStats {
  ServerStats(
    rooms: Int,
    clients: Int,
    phi_validated: Bool,
  )
}

/// Server state
pub type ServerState {
  ServerState(rooms: Dict(String, RoomState))
}

/// Handle server messages
fn handle_server_message(
  message: ServerMessage,
  state: ServerState,
) -> actor.Next(ServerMessage, ServerState) {
  case message {
    ClientJoin(room_id, client_id, reply) -> {
      let room = case dict.get(state.rooms, room_id) {
        Ok(r) -> r
        Error(_) -> new_room(room_id)
      }
      let updated_room = room_add_client(room, client_id)
      let new_state = ServerState(
        rooms: dict.insert(state.rooms, room_id, updated_room),
      )
      process.send(reply, updated_room)
      actor.continue(new_state)
    }
    
    ClientLeave(room_id, client_id) -> {
      case dict.get(state.rooms, room_id) {
        Ok(room) -> {
          let updated_room = room_remove_client(room, client_id)
          let new_rooms = case list.is_empty(updated_room.clients) {
            True -> dict.delete(state.rooms, room_id)
            False -> dict.insert(state.rooms, room_id, updated_room)
          }
          actor.continue(ServerState(rooms: new_rooms))
        }
        Error(_) -> actor.continue(state)
      }
    }
    
    UpdateState(room_id, _client_id, update) -> {
      case dict.get(state.rooms, room_id) {
        Ok(room) -> {
          let updated_room = case update {
            ScrollUpdate(value, timestamp) ->
              RoomState(
                ..room,
                scroll_position: register_set(room.scroll_position, value, timestamp),
              )
            SectionUpdate(value, timestamp) ->
              RoomState(
                ..room,
                active_section: register_set(room.active_section, value, timestamp),
              )
            ThemeUpdate(value, timestamp) ->
              RoomState(
                ..room,
                theme: register_set(room.theme, value, timestamp),
              )
            ViewCountIncrement(node_id) ->
              RoomState(
                ..room,
                view_count: counter_increment(room.view_count, node_id),
              )
          }
          actor.continue(ServerState(
            rooms: dict.insert(state.rooms, room_id, updated_room),
          ))
        }
        Error(_) -> actor.continue(state)
      }
    }
    
    UpdateCursor(room_id, client_id, x, y) -> {
      case dict.get(state.rooms, room_id) {
        Ok(room) -> {
          let timestamp = erlang_system_time()
          let updated_room = room_update_cursor(room, client_id, x, y, timestamp)
          actor.continue(ServerState(
            rooms: dict.insert(state.rooms, room_id, updated_room),
          ))
        }
        Error(_) -> actor.continue(state)
      }
    }
    
    GetRoom(room_id, reply) -> {
      let room = dict.get(state.rooms, room_id) |> option.from_result
      process.send(reply, room)
      actor.continue(state)
    }
    
    GetStats(reply) -> {
      let client_count = dict.values(state.rooms)
        |> list.map(fn(r) { list.length(r.clients) })
        |> list.fold(0, int.add)
      
      process.send(reply, ServerStats(
        rooms: dict.size(state.rooms),
        clients: client_count,
        phi_validated: validate_golden_identity(),
      ))
      actor.continue(state)
    }
  }
}

// External function for system time
@external(erlang, "erlang", "system_time")
fn erlang_system_time() -> Int

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Health check response
fn health_response(server: Subject(ServerMessage)) -> Response(mist.ResponseData) {
  let stats_subject = process.new_subject()
  process.send(server, GetStats(stats_subject))
  
  // Wait for response with timeout
  let stats = case process.receive(stats_subject, 1000) {
    Ok(s) -> s
    Error(_) -> ServerStats(rooms: 0, clients: 0, phi_validated: False)
  }
  
  let body = json.object([
    #("status", json.string("ok")),
    #("version", json.string("v22.φ")),
    #("rooms", json.int(stats.rooms)),
    #("clients", json.int(stats.clients)),
    #("phi", json.float(phi)),
    #("phi_validated", json.bool(stats.phi_validated)),
    #("golden_identity", json.string("φ² + 1/φ² = 3")),
  ])
  |> json.to_string
  
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_builder.from_string(body)))
}

/// Not found response
fn not_found_response() -> Response(mist.ResponseData) {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_builder.from_string("Not Found")))
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEBSOCKET HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

/// WebSocket connection state
pub type WsState {
  WsState(
    server: Subject(ServerMessage),
    client_id: String,
    room_id: String,
  )
}

/// Handle WebSocket message
fn handle_ws_message(
  state: WsState,
  message: WebsocketMessage,
) -> Result(WsState, Nil) {
  case message {
    Text(text) -> {
      // Parse JSON message
      case json.decode(text, dynamic.dynamic) {
        Ok(data) -> {
          handle_client_message(state, data)
          Ok(state)
        }
        Error(_) -> Ok(state)
      }
    }
    Binary(_) -> Ok(state)
    _ -> Ok(state)
  }
}

/// Handle parsed client message
fn handle_client_message(state: WsState, data: Dynamic) -> Nil {
  // Extract message type
  let msg_type = dynamic.field("type", dynamic.string)(data)
  
  case msg_type {
    Ok("cursor") -> {
      let x = dynamic.field("x", dynamic.float)(data) |> result.unwrap(0.0)
      let y = dynamic.field("y", dynamic.float)(data) |> result.unwrap(0.0)
      process.send(state.server, UpdateCursor(state.room_id, state.client_id, x, y))
    }
    Ok("scroll") -> {
      let value = dynamic.field("value", dynamic.int)(data) |> result.unwrap(0)
      let timestamp = dynamic.field("timestamp", dynamic.int)(data) |> result.unwrap(0)
      process.send(state.server, UpdateState(
        state.room_id,
        state.client_id,
        ScrollUpdate(value, timestamp),
      ))
    }
    Ok("section") -> {
      let value = dynamic.field("value", dynamic.string)(data) |> result.unwrap("hero")
      let timestamp = dynamic.field("timestamp", dynamic.int)(data) |> result.unwrap(0)
      process.send(state.server, UpdateState(
        state.room_id,
        state.client_id,
        SectionUpdate(value, timestamp),
      ))
    }
    Ok("viewCount") -> {
      process.send(state.server, UpdateState(
        state.room_id,
        state.client_id,
        ViewCountIncrement(state.client_id),
      ))
    }
    _ -> Nil
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() {
  io.println("⚡ TRINITY Collaboration Server v22.φ")
  io.println("⚡ Built with Gleam on BEAM")
  io.println("⚡ φ² + 1/φ² = " <> float.to_string(phi_sq +. 1.0 /. phi_sq))
  io.println("⚡ Golden Identity validated: " <> string.inspect(validate_golden_identity()))
  
  // Start server actor
  let assert Ok(server) = actor.start(
    ServerState(rooms: dict.new()),
    handle_server_message,
  )
  
  // Start HTTP/WebSocket server
  let port = 8081
  io.println("⚡ Listening on port " <> int.to_string(port))
  
  let assert Ok(_) = mist.new(fn(req: Request(mist.Connection)) {
    case request.path_segments(req) {
      ["health"] -> health_response(server)
      ["ws"] -> {
        // Upgrade to WebSocket
        let client_id = generate_client_id()
        let room_id = get_room_from_query(req)
        
        // Join room
        let room_subject = process.new_subject()
        process.send(server, ClientJoin(room_id, client_id, room_subject))
        
        mist.websocket(
          request: req,
          on_init: fn(_conn) {
            #(WsState(server: server, client_id: client_id, room_id: room_id), None)
          },
          on_close: fn(state) {
            process.send(server, ClientLeave(state.room_id, state.client_id))
          },
          handler: fn(state, _conn, message) {
            case handle_ws_message(state, message) {
              Ok(new_state) -> actor.continue(new_state)
              Error(_) -> actor.Stop(process.Normal)
            }
          },
        )
      }
      _ -> not_found_response()
    }
  })
  |> mist.port(port)
  |> mist.start_http
  
  // Keep running
  process.sleep_forever()
}

/// Generate unique client ID
fn generate_client_id() -> String {
  let timestamp = erlang_system_time()
  "client-" <> int.to_string(timestamp)
}

/// Get room ID from query string
fn get_room_from_query(req: Request(mist.Connection)) -> String {
  case request.get_query(req) {
    Ok(params) -> {
      list.find(params, fn(p) { p.0 == "room" })
      |> result.map(fn(p) { p.1 })
      |> result.unwrap("default")
    }
    Error(_) -> "default"
  }
}
