// Generated manually from specs/hooks.vibee
// TODO: Regenerate with vibeec when available

import gleam/list
import gleam/string
import gleam/result
import gleam/option.{type Option, None, Some}
import gleam/int
import simplifile
import shellout

pub type HookType {
  PreCommit
  PrePush
  PostCommit
}

pub type HookConfig {
  HookConfig(hook_type: HookType, script_content: String, executable: Bool)
}

pub type InstallResult {
  InstallResult(
    success: Bool,
    installed_hooks: List(HookType),
    backups_created: List(String),
    error: Option(String),
  )
}

pub type HookCheckResult {
  HookCheckResult(
    allow_action: Bool,
    violations: List(scanner.Violation),
    checked_files: List(String),
    error_message: Option(String),
  )
}

import honeycomb/dogfooding/scanner

pub fn install_hooks(repo_path: String) -> Result(InstallResult, String) {
  case is_git_repo(repo_path) {
    False -> Error("Not a git repository")
    True -> {
      let hooks_to_install = [PreCommit, PrePush]
      let results =
        list.map(hooks_to_install, fn(hook_type) {
          install_hook(repo_path, hook_type)
        })

      let successes = list.filter_map(results, fn(r) { r })
      let installed_count = list.length(successes)

      case installed_count == list.length(hooks_to_install) {
        True ->
          Ok(InstallResult(
            success: True,
            installed_hooks: hooks_to_install,
            backups_created: [],
            error: None,
          ))
        False ->
          Error("Failed to install some hooks")
      }
    }
  }
}

pub fn install_hook(
  repo_path: String,
  hook_type: HookType,
) -> Result(String, String) {
  let hooks_dir = get_hooks_dir(repo_path)
  let hook_name = hook_type_to_name(hook_type)
  let hook_path = hooks_dir <> "/" <> hook_name

  // Check if hook already exists
  case simplifile.verify_is_file(hook_path) {
    Ok(_) -> {
      let _ = backup_hook(hook_path)
      Nil
    }
    Error(_) -> Nil
  }

  // Create hook script
  let script = case hook_type {
    PreCommit -> create_pre_commit_script()
    PrePush -> create_pre_push_script()
    PostCommit -> ""
  }

  case simplifile.write(hook_path, script) {
    Ok(_) -> {
      case make_executable(hook_path) {
        Ok(_) -> Ok(hook_path)
        Error(err) -> Error(err)
      }
    }
    Error(_) -> Error("Failed to write hook script")
  }
}

pub fn create_pre_commit_script() -> String {
  "#!/usr/bin/env bash
# VIBEE Dogfooding Pre-Commit Hook
# Auto-generated - do not edit manually

echo \"🔍 VIBEE: Checking staged files...\"

# Get staged .gleam files in honeycomb/
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '^honeycomb/.*\\.gleam$')

if [ -z \"$STAGED_FILES\" ]; then
  echo \"✅ No honeycomb/ files staged\"
  exit 0
fi

# Run scanner
cd \"$(git rev-parse --show-toplevel)\"
gleam run -m honeycomb/dogfooding/cli -- scan $STAGED_FILES

if [ $? -ne 0 ]; then
  echo \"❌ Violations found! Fix or use 'git commit --no-verify' to skip.\"
  exit 1
fi

echo \"✅ All checks passed\"
exit 0
"
}

pub fn create_pre_push_script() -> String {
  "#!/usr/bin/env bash
# VIBEE Dogfooding Pre-Push Hook
# Auto-generated - do not edit manually

echo \"🔍 VIBEE: Checking all honeycomb/ files...\"

# Run full scan
cd \"$(git rev-parse --show-toplevel)\"
gleam run -m honeycomb/dogfooding/cli -- scan honeycomb/

if [ $? -ne 0 ]; then
  echo \"❌ Violations found! Fix before pushing.\"
  exit 1
fi

echo \"✅ All checks passed\"
exit 0
"
}

pub fn make_executable(file_path: String) -> Result(Nil, String) {
  case shellout.command("chmod", ["+x", file_path], ".", []) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Failed to make file executable")
  }
}

pub fn backup_hook(hook_path: String) -> Result(String, String) {
  let timestamp = 1_704_067_200
  let backup_path = hook_path <> ".backup." <> int.to_string(timestamp)

  case simplifile.copy_file(hook_path, backup_path) {
    Ok(_) -> Ok(backup_path)
    Error(_) -> Error("Failed to create backup")
  }
}

pub fn get_staged_files() -> Result(List(String), String) {
  case
    shellout.command(
      "git",
      ["diff", "--cached", "--name-only", "--diff-filter=ACM"],
      ".",
      [],
    )
  {
    Ok(output) -> {
      let files = string.split(output, "\n")
      Ok(list.filter(files, fn(f) { f != "" }))
    }
    Error(_) -> Error("Failed to get staged files")
  }
}

pub fn filter_honeycomb_gleam_files(files: List(String)) -> List(String) {
  list.filter(files, fn(file) {
    string.starts_with(file, "honeycomb/") && string.ends_with(file, ".gleam")
  })
}

pub fn run_hook_check(
  files: List(String),
  hook_type: HookType,
) -> HookCheckResult {
  // Simplified implementation
  HookCheckResult(
    allow_action: True,
    violations: [],
    checked_files: files,
    error_message: None,
  )
}

pub fn uninstall_hooks(repo_path: String) -> Result(Nil, String) {
  let hooks_dir = get_hooks_dir(repo_path)
  let hooks_to_remove = [PreCommit, PrePush]

  list.each(hooks_to_remove, fn(hook_type) {
    let hook_name = hook_type_to_name(hook_type)
    let hook_path = hooks_dir <> "/" <> hook_name
    let _ = simplifile.delete(hook_path)
    Nil
  })

  Ok(Nil)
}

pub fn is_git_repo(path: String) -> Bool {
  let git_dir = path <> "/.git"
  case simplifile.verify_is_directory(git_dir) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn get_hooks_dir(repo_path: String) -> String {
  repo_path <> "/.git/hooks"
}

fn hook_type_to_name(hook_type: HookType) -> String {
  case hook_type {
    PreCommit -> "pre-commit"
    PrePush -> "pre-push"
    PostCommit -> "post-commit"
  }
}
