// VIBEE Dogfooding CLI
// Command-line interface for spec enforcement

import gleam/io
import gleam/list
import gleam/string
import gleam/result
import honeycomb/dogfooding/scanner
import honeycomb/dogfooding/autofix
import honeycomb/dogfooding/hooks
import honeycomb/dogfooding/watcher

pub fn main() {
  io.println("🔍 VIBEE Dogfooding System")
  io.println("Enforcing spec-driven development")
  io.println("")
}

pub fn scan_command(paths: List(String)) -> Result(Nil, String) {
  io.println("📊 Scanning files for violations...")

  let config = scanner.default_scan_config()

  let results =
    list.filter_map(paths, fn(path) {
      case string.ends_with(path, ".gleam") {
        True -> scanner.scan_file(path, config)
        False -> scanner.scan_directory(path, config)
      }
    })

  let all_results = list.flatten(results)
  let total_violations =
    list.fold(all_results, 0, fn(acc, result) {
      acc + list.length(result.violations)
    })

  case total_violations {
    0 -> {
      io.println("✅ No violations found!")
      Ok(Nil)
    }
    _ -> {
      io.println("❌ Found " <> string.inspect(total_violations) <> " violations:")
      list.each(all_results, fn(result) {
        list.each(result.violations, fn(violation) {
          io.println("  " <> scanner.format_violation(violation))
        })
      })
      Error("Violations found")
    }
  }
}

pub fn fix_command(paths: List(String)) -> Result(Nil, String) {
  io.println("🔧 Auto-fixing violations...")

  let config = scanner.default_scan_config()
  let fix_config = autofix.default_fix_config()

  let results =
    list.filter_map(paths, fn(path) { scanner.scan_file(path, config) })

  let all_violations =
    list.flatten(list.map(results, fn(result) { result.violations }))

  let fix_results = autofix.fix_all_violations(all_violations, fix_config)

  let fixed_count =
    list.length(list.filter(fix_results, fn(r) { r.fixed }))

  io.println(
    "✅ Fixed " <> string.inspect(fixed_count) <> " violations",
  )

  Ok(Nil)
}

pub fn install_hooks_command() -> Result(Nil, String) {
  io.println("🪝 Installing git hooks...")

  case hooks.install_hooks(".") {
    Ok(result) -> {
      io.println("✅ Installed hooks:")
      list.each(result.installed_hooks, fn(hook) {
        io.println("  - " <> string.inspect(hook))
      })
      Ok(Nil)
    }
    Error(err) -> {
      io.println("❌ Failed to install hooks: " <> err)
      Error(err)
    }
  }
}

pub fn uninstall_hooks_command() -> Result(Nil, String) {
  io.println("🗑️  Uninstalling git hooks...")

  case hooks.uninstall_hooks(".") {
    Ok(_) -> {
      io.println("✅ Hooks uninstalled")
      Ok(Nil)
    }
    Error(err) -> {
      io.println("❌ Failed to uninstall hooks: " <> err)
      Error(err)
    }
  }
}

pub fn watch_command() -> Result(Nil, String) {
  io.println("👁️  Starting file watcher...")

  let config = watcher.default_config()

  case watcher.start_watcher(config) {
    Ok(_state) -> {
      io.println("✅ Watching honeycomb/ for changes")
      io.println("Press Ctrl+C to stop")
      // TODO: Implement actual watching loop
      Ok(Nil)
    }
    Error(err) -> {
      io.println("❌ Failed to start watcher: " <> err)
      Error(err)
    }
  }
}

pub fn status_command() -> Result(Nil, String) {
  io.println("📊 VIBEE Dogfooding Status")
  io.println("")

  // Check if hooks are installed
  case hooks.is_git_repo(".") {
    True -> {
      io.println("✅ Git repository detected")

      // Check for hooks
      let hooks_dir = hooks.get_hooks_dir(".")
      io.println("📁 Hooks directory: " <> hooks_dir)
    }
    False -> {
      io.println("❌ Not a git repository")
    }
  }

  // Scan honeycomb/ for violations
  io.println("")
  io.println("🔍 Scanning honeycomb/ for violations...")

  let config = scanner.default_scan_config()
  case scanner.scan_directory("honeycomb/", config) {
    Ok(results) -> {
      let total_violations =
        list.fold(results, 0, fn(acc, result) {
          acc + list.length(result.violations)
        })

      case total_violations {
        0 -> io.println("✅ No violations found")
        _ ->
          io.println(
            "⚠️  Found " <> string.inspect(total_violations) <> " violations",
          )
      }
    }
    Error(err) -> {
      io.println("❌ Scan failed: " <> err)
    }
  }

  Ok(Nil)
}
