import gleam/bit_array
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import glisten.{Packet}
import http/internal/http.{
  type Request as InternalRequest, type Response as InternalResponse, Request,
  Response,
}
import http/internal/utils.{merge_dicts}
import http/router.{type Router as InternalRouter}

pub type Request =
  InternalRequest

pub type Response =
  InternalResponse

pub type Router =
  InternalRouter

pub type ReadError {
  StopSequenceNotFound
}

type RequestLine {
  RequestLine(method: String, path: String, http_version: String)
}

pub fn handle(
  routes: Dict(String, router.RouteHandler),
  route: String,
  handler: router.RouteHandler,
) {
  dict.insert(routes, route, handler)
}

fn handle_request(
  router: router.Router,
  route route: String,
  request req: Request,
) {
  case dict.get(router.routes, route) {
    Ok(handler) -> handler(req)
    Error(_) ->
      Response(
        status: 404,
        status_msg: "Not Found",
        http_version: "HTTP/1.1",
        body: None,
      )
  }
}

fn get_http_status_msg(status: Int) -> String {
  case status {
    200 -> "OK"
    201 -> "Created"
    204 -> "No Content"
    400 -> "Bad Request"
    500 -> "Internal Server Error"
    _ -> "Unknown"
  }
}

fn read(str: String, stop: String) -> Result(#(String, String), ReadError) {
  case string.split_once(str, stop) {
    Ok(res) -> Ok(res)
    Error(_) -> Error(StopSequenceNotFound)
  }
}

fn parse_request_line(line: String) {
  case string.split(line, on: " ") {
    [] -> Error(StopSequenceNotFound)
    [method, path, http_version] ->
      Ok(RequestLine(method: method, path: path, http_version: http_version))
    _ -> Error(StopSequenceNotFound)
  }
}

fn parse_header(header_str: String) {
  case string.split_once(header_str, ":") {
    Ok(#(name, value)) -> {
      Ok(dict.from_list([#(name, value)]))
    }
    Error(_) -> Error(StopSequenceNotFound)
  }
}

fn parse_headers(line: String) {
  let headers_pairs =
    string.split(line, on: "\r\n")
    |> list.map(parse_header)
    |> result.values
  case headers_pairs {
    [] -> dict.new()
    pairs -> merge_dicts(pairs)
  }
}

pub fn parse_message(msg: String) -> Result(Request, ReadError) {
  use #(req_line_str, msg) <- result.try(read(msg, "\r\n"))
  use #(headers_str, body) <- result.try(read(msg, "\r\n\r\n"))

  use req_line <- result.try(parse_request_line(req_line_str))
  let headers = parse_headers(headers_str)

  Ok(
    Request(
      method: req_line.method,
      path: req_line.path,
      http_version: req_line.http_version,
      headers: headers,
      body: case body {
        "" -> None
        body -> Some(body)
      },
    ),
  )
}

pub fn create_response(
  status: Int,
  req: Request,
  body: Option(String),
) -> Response {
  let status_msg = get_http_status_msg(status)
  Response(
    status: status,
    status_msg: status_msg,
    http_version: req.http_version,
    body: body,
  )
}

pub type AddRouteFn =
  fn(String, router.RouteHandler) -> Nil

pub type Server {
  Server(router: Router)
}

pub fn serve(port port: Int, router router: Router) {
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg) = msg
      let assert Ok(msg) = bit_array.to_string(msg)
      let assert Ok(req) = parse_message(msg)
      let res = handle_request(router, route: req.path, request: req)
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
    |> glisten.serve(port)

  process.sleep_forever()
}
