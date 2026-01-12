// Generated manually from specs/watcher.vibee
// TODO: Regenerate with vibeec when available

import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import gleam/result
import gleam/option.{type Option, None, Some}

pub type FilterType {
  Include
  Exclude
}

pub type PathFilter {
  PathFilter(pattern: String, filter_type: FilterType, reason: String)
}

pub type WatchConfig {
  WatchConfig(
    path: String,
    recursive: Bool,
    debounce_ms: Int,
    filters: List(PathFilter),
  )
}

pub type EventType {
  Create
  Modify
  Delete
  Rename
}

pub type FileEvent {
  FileEvent(event_type: EventType, path: String, timestamp: Int)
}

pub type WatcherState {
  WatcherState(
    config: WatchConfig,
    event_queue: List(FileEvent),
    last_processed: Dict(String, Int),
  )
}

pub fn default_config() -> WatchConfig {
  WatchConfig(
    path: "honeycomb/",
    recursive: True,
    debounce_ms: 200,
    filters: [
      PathFilter("honeycomb/**/*.gleam", Include, "honeycomb_gleam_file"),
      PathFilter("build/**", Exclude, "build_artifact"),
      PathFilter(".git/**", Exclude, "git_directory"),
      PathFilter("gleam/src/**", Exclude, "gleam_src_excluded"),
      PathFilter("**/*.beam", Exclude, "erlang_beam_file"),
      PathFilter("**/node_modules/**", Exclude, "node_modules"),
    ],
  )
}

pub fn start_watcher(config: WatchConfig) -> Result(WatcherState, String) {
  Ok(WatcherState(
    config: config,
    event_queue: [],
    last_processed: dict.new(),
  ))
}

pub fn handle_event(
  state: WatcherState,
  event: FileEvent,
) -> Result(WatcherState, String) {
  case should_process(state, event) {
    True -> {
      let new_queue = [event, ..state.event_queue]
      let new_last_processed =
        dict.insert(state.last_processed, event.path, event.timestamp)
      Ok(WatcherState(..state, event_queue: new_queue, last_processed: new_last_processed))
    }
    False -> Ok(state)
  }
}

pub fn should_process(state: WatcherState, event: FileEvent) -> Bool {
  case filter_path(event.path, state.config.filters) {
    Ok(_) -> debounce_check(state, event.path, event.timestamp)
    Error(_) -> False
  }
}

pub fn filter_path(
  path: String,
  filters: List(PathFilter),
) -> Result(Nil, String) {
  case is_in_honeycomb(path) && is_gleam_file(path) && !is_build_artifact(path) {
    True -> Ok(Nil)
    False -> Error("Path excluded by filters")
  }
}

pub fn is_gleam_file(path: String) -> Bool {
  string.ends_with(path, ".gleam")
}

pub fn is_in_honeycomb(path: String) -> Bool {
  string.starts_with(path, "honeycomb/")
}

pub fn is_build_artifact(path: String) -> Bool {
  string.starts_with(path, "build/")
  || string.starts_with(path, ".git/")
  || string.contains(path, "node_modules")
  || string.ends_with(path, ".beam")
}

pub fn debounce_check(
  state: WatcherState,
  path: String,
  current_time: Int,
) -> Bool {
  case dict.get(state.last_processed, path) {
    Ok(last_time) -> {
      let elapsed = current_time - last_time
      elapsed >= state.config.debounce_ms
    }
    Error(_) -> True
  }
}

pub fn update_last_processed(
  state: WatcherState,
  path: String,
  timestamp: Int,
) -> WatcherState {
  let new_last_processed =
    dict.insert(state.last_processed, path, timestamp)
  WatcherState(..state, last_processed: new_last_processed)
}
