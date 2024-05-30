import gleam/dict.{type Dict}
import gleam/option.{type Option}

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
