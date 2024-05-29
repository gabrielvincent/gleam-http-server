import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type ReadError {
  StopSequenceNotFound
}

pub type Request {
  Request(
    method: String,
    path: String,
    http_version: String,
    headers: Dict(String, String),
    body: Option(String),
  )
}

pub type Response {
  Response(
    status: Int,
    status_msg: String,
    http_version: String,
    body: Option(String),
  )
}

type RequestLine {
  RequestLine(method: String, path: String, http_version: String)
}

pub type RouteHandler =
  fn(Request) -> Response

pub type Router {
  Router(routes: Dict(String, RouteHandler))
}

pub fn create_router() {
  Router(routes: dict.new())
}

pub fn add_route(router: Router, route: String, handler: RouteHandler) {
  let routes = router.routes
  let routes = dict.insert(routes, route, handler)
  Router(routes: routes)
}

pub fn handle_request(router: Router, route route: String, request req: Request) {
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

pub fn merge_dicts(dicts: List(Dict(String, String))) -> Dict(String, String) {
  list.fold(dicts, dict.new(), fn(dict, acc) { dict.merge(acc, dict) })
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
