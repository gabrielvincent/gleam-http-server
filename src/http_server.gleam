import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/int
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/string
import glisten.{Packet}
import http

pub fn main() {
  let router = http.create_router()
  let router =
    http.add_route(router, "/", fn(req) { http.create_response(204, req, None) })
  let router =
    http.add_route(router, "/with-body", fn(req) {
      http.create_response(200, req, Some("body content"))
    })

  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg) = msg
      let assert Ok(msg) = bit_array.to_string(msg)
      let assert Ok(req) = http.parse_message(msg)
      let res = http.handle_request(router, route: req.path, request: req)
      let body = option.unwrap(res.body, "")
      let body_size = string.byte_size(body)
      let content_length_header = case body_size {
        0 -> ""
        _ -> "Content-Length: " <> int.to_string(body_size)
      }
      let response =
        res.http_version
        <> " "
        <> int.to_string(res.status)
        <> " "
        <> res.status_msg
        <> "\r\n"
        // Headers go here
        <> content_length_header
        <> "\r\n"
        <> "\r\n"
        <> body
        <> "\r\n\r\n"

      let assert Ok(_) = glisten.send(conn, bytes_builder.from_string(response))
      actor.continue(state)
    })
    |> glisten.serve(4221)

  process.sleep_forever()
}
