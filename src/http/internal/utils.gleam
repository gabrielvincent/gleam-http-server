import gleam/dict.{type Dict}
import gleam/list

pub fn merge_dicts(dicts: List(Dict(String, String))) -> Dict(String, String) {
  list.fold(dicts, dict.new(), fn(dict, acc) { dict.merge(acc, dict) })
}
