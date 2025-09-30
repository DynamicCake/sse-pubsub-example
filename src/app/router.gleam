import app/broadcaster
import app/sse
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/result
import mist
import wisp
import wisp/wisp_mist

pub fn handle_mist(
  req: request.Request(mist.Connection),
  secret_key_base: String,
  broadcaster: broadcaster.Broadcaster,
) -> response.Response(mist.ResponseData) {
  case wisp.path_segments(req) {
    ["sse"] ->
      sse.with_process(
        req,
        // Replace with a number that suits your needs
        10_000,
        fn(subscriber) { broadcaster.subscribe(broadcaster, subscriber) },
      )
    _ -> wisp_mist.handler(handle_request(_, broadcaster), secret_key_base)(req)
  }
}

pub fn handle_request(
  req: wisp.Request,
  broadcaster: broadcaster.Broadcaster,
) -> wisp.Response {
  case wisp.path_segments(req) {
    ["greet"] -> {
      wisp.get_query(req)
      |> list.key_find("name")
      |> result.unwrap("world")
      |> broadcaster.greet(broadcaster)
      wisp.ok()
    }
    [] ->
      wisp.html_response(
        "<p> Greet someone at <code>/greet?name=world</code> and hear the greetings at <code>/sse</code> </p>",
        200,
      )
    _ -> wisp.not_found()
  }
}
