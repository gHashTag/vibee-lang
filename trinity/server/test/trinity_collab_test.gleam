// TRINITY Collaboration Server Tests
// φ² + 1/φ² = 3

import gleeunit
import gleeunit/should
import trinity_collab.{
  new_counter, counter_increment, counter_value, counter_merge,
  new_register, register_set, register_merge,
  new_room, room_add_client, room_remove_client,
  validate_golden_identity,
}
import phi

pub fn main() {
  gleeunit.main()
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ CONSTANTS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn phi_constant_test() {
  phi.phi
  |> should.equal(1.618033988749895)
}

pub fn phi_inv_constant_test() {
  phi.phi_inv
  |> should.equal(0.618033988749895)
}

pub fn golden_identity_test() {
  validate_golden_identity()
  |> should.be_true
}

pub fn phi_validate_golden_identity_test() {
  phi.validate_golden_identity()
  |> should.be_true
}

// ═══════════════════════════════════════════════════════════════════════════════
// CRDT COUNTER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn counter_new_test() {
  let counter = new_counter()
  counter_value(counter)
  |> should.equal(0)
}

pub fn counter_increment_test() {
  let counter = new_counter()
    |> counter_increment("node1")
    |> counter_increment("node1")
    |> counter_increment("node2")
  
  counter_value(counter)
  |> should.equal(3)
}

pub fn counter_merge_test() {
  let counter1 = new_counter()
    |> counter_increment("node1")
    |> counter_increment("node1")
  
  let counter2 = new_counter()
    |> counter_increment("node2")
    |> counter_increment("node2")
    |> counter_increment("node2")
  
  let merged = counter_merge(counter1, counter2)
  
  counter_value(merged)
  |> should.equal(5)
}

pub fn counter_merge_idempotent_test() {
  let counter = new_counter()
    |> counter_increment("node1")
  
  let merged = counter_merge(counter, counter)
  
  counter_value(merged)
  |> should.equal(1)
}

// ═══════════════════════════════════════════════════════════════════════════════
// LWW REGISTER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn register_new_test() {
  let register = new_register()
  register.timestamp
  |> should.equal(0)
}

pub fn register_set_test() {
  let register = new_register()
    |> register_set("hello", 100)
  
  register.timestamp
  |> should.equal(100)
}

pub fn register_merge_lww_test() {
  let register1 = new_register()
    |> register_set("old", 100)
  
  let register2 = new_register()
    |> register_set("new", 200)
  
  let merged = register_merge(register1, register2)
  
  merged.timestamp
  |> should.equal(200)
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOM TESTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn room_new_test() {
  let room = new_room("test-room")
  room.id
  |> should.equal("test-room")
}

pub fn room_add_client_test() {
  let room = new_room("test-room")
    |> room_add_client("client1")
    |> room_add_client("client2")
  
  room.clients
  |> should.equal(["client2", "client1"])
}

pub fn room_remove_client_test() {
  let room = new_room("test-room")
    |> room_add_client("client1")
    |> room_add_client("client2")
    |> room_remove_client("client1")
  
  room.clients
  |> should.equal(["client2"])
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ MATH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn space_test() {
  phi.space(0)
  |> should.equal(8)
  
  phi.space(1)
  |> should.equal(13)
  
  phi.space(2)
  |> should.equal(21)
}

pub fn fibonacci_test() {
  phi.fibonacci(0)
  |> should.equal(1)
  
  phi.fibonacci(5)
  |> should.equal(8)
  
  phi.fibonacci(10)
  |> should.equal(89)
}

pub fn is_golden_ratio_test() {
  phi.is_golden_ratio(8.0, 13.0)
  |> should.be_true
  
  phi.is_golden_ratio(1.0, 2.0)
  |> should.be_false
}

pub fn btree_branching_factor_test() {
  phi.btree_branching_factor()
  |> should.equal(2.618033988749895)
}
