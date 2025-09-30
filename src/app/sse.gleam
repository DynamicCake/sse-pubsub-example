//// Server Sent Events actor, there is one actor per event 

import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/string_tree.{type StringTree}
import mist
import mist/internal/http
import repeatedly
import wisp

pub type SseActor =
  Subject(SseMsg)

pub type SseMsg {
  // You may want to make this only allow typed messages
  BroadcastMsg(tag: String, body: StringTree)
  Down
}

pub fn send(subj: Subject(SseMsg), tag: String, json: StringTree) {
  let assert Ok(owner) = process.subject_owner(subj)
  let assert True = process.is_alive(owner)
  process.send(subj, BroadcastMsg(tag, json))
}

/// Create an SSE connection
pub fn with_process(
  req: request.Request(http.Connection),
  heartbeat_delay: Int,
  callback: fn(Subject(SseMsg)) -> Nil,
) {
  // TODO: Implement hadling for the `Last-Event-ID` header
  mist.server_sent_events(
    req,
    response.new(200)
      // This is here so nginx doesn't screw you over
      // This was a pain in the ass to fix for me, thank me later
      |> wisp.set_header("X-Accel-Buffering", "no"),
    init: fn(subj: Subject(SseMsg)) {
      callback(subj)
      EventState(heartbeat: repeater(subj, heartbeat_delay), count: 1)
      |> actor.initialised()
      |> Ok()
    },
    loop: fn(state, message, conn) {
      case message {
        BroadcastMsg(tag, body) -> {
          let event =
            mist.event(body)
            |> mist.event_id(state.count |> int.to_string)
            |> mist.event_name(tag)
          case mist.send_event(conn, event) {
            Ok(_) -> {
              actor.continue(EventState(..state, count: state.count + 1))
            }
            Error(_) -> {
              actor.stop()
            }
          }
        }
        Down -> {
          repeatedly.stop(state.heartbeat)
          actor.stop()
        }
      }
    },
  )
}

pub fn repeater(subj, heartbeat_delay) {
  repeatedly.call(heartbeat_delay, Nil, fn(_state, i) {
    process.send(
      subj,
      BroadcastMsg(
        tag: "heartbeat",
        body: [#("count", json.int(i))]
          |> json.object()
          |> json.to_string_tree(),
      ),
    )
  })
}

pub type EventState {
  EventState(
    count: Int,
    /// Server sent events should have a heartbeat to keep the connection alive
    heartbeat: repeatedly.Repeater(Nil),
  )
}
