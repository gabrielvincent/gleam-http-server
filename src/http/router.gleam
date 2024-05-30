import gleam/dict.{type Dict}
import http/internal/http.{type Request, type Response}

pub type RouteHandler =
  fn(Request) -> Response

pub type Router {
  Router(routes: Dict(String, RouteHandler))
}
