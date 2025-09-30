import app/broadcaster
import app/router
import gleam/erlang/process
import mist
import wisp

pub fn main() -> Nil {
  let secret_key_base = wisp.random_string(64)
  let assert Ok(broadcaster) = broadcaster.new()

  let assert Ok(_) =
    mist.new(router.handle_mist(_, secret_key_base, broadcaster.data))
    // |> mist.bind("0.0.0.0")
    |> mist.start

  process.sleep_forever()
}
