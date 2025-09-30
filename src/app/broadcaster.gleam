//// The pubsub that `SseActor`s subscribe to.
//// Typically there is only ever one.

import app/sse
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/list
import gleam/otp/actor

pub type Broadcaster =
  Subject(BroadcasterMsg)

pub fn new() -> Result(actor.Started(Broadcaster), actor.StartError) {
  actor.new(ManagerState([]))
  |> actor.on_message(handle_message)
  |> actor.start()
}

/// Subscribe with a pid subject
pub fn subscribe(pubsub: Broadcaster, subj: sse.SseActor) {
  let assert Ok(pid) = process.subject_owner(subj)
  actor.send(pubsub, Subscribe(Subscriber(subj: subj, pid:)))
}

pub fn greet(msg: String, pubsub: Broadcaster) {
  actor.send(pubsub, Greet(msg))
}

pub fn shutdown(pubsub: Broadcaster) {
  actor.send(pubsub, Down)
}

fn handle_message(
  state: ManagerState,
  message: BroadcasterMsg,
) -> actor.Next(ManagerState, BroadcasterMsg) {
  let broadcast = fn(
    tag: String,
    json: json.Json,
    // Keep if you want to do permission checks (which you usually would want to)
    callback: fn(Subscriber) -> Bool,
  ) {
    // loop through and prune dead processes
    let new_list =
      list.filter(state.subjects, fn(sub) {
        use <- bool.guard(
          sub.pid
            |> process.is_alive()
            |> bool.negate,
          False,
        )
        case callback(sub) {
          True -> sse.send(sub.subj, tag, json |> json.to_string_tree)
          False -> Nil
        }
        True
      })
    new_list
    |> ManagerState
    |> actor.continue
  }

  case message {
    Subscribe(subscriber) -> {
      actor.continue(ManagerState(
        subjects: state.subjects |> list.prepend(subscriber),
      ))
    }
    Greet(name) -> {
      broadcast(
        "greeting",
        json.object([#("message", json.string("Hello, " <> name <> "!"))]),
        // Since this sends to everyone, it always returns true
        fn(_) { True },
      )
    }
    Down -> actor.stop()
  }
}

type ManagerState {
  ManagerState(subjects: List(Subscriber))
}

type Subscriber {
  // You might want to inclue permissions information
  Subscriber(subj: sse.SseActor, pid: process.Pid)
}

pub opaque type BroadcasterMsg {
  Subscribe(Subscriber)
  // Define a message here
  Greet(String)
  Down
}
