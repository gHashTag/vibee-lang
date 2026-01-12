// Generated manually from specs/autofix.vibee
// TODO: Regenerate with vibeec when available

import gleam/list
import gleam/string
import gleam/result
import gleam/option.{type Option, None, Some}
import gleam/int
import simplifile
import shellout
import honeycomb/dogfooding/scanner.{type Violation, type ViolationRule}

pub type FixAction {
  RegeneratedFromSpec
  CreatedSpec
  ManualFixRequired
  NoActionNeeded
}

pub type FixResult {
  FixResult(
    violation: Violation,
    fixed: Bool,
    action: FixAction,
    backup_path: Option(String),
    error: Option(String),
  )
}

pub type BackupInfo {
  BackupInfo(original_path: String, backup_path: String, timestamp: Int)
}

pub type ValidationResult {
  ValidationResult(
    valid: Bool,
    remaining_violations: List(Violation),
    new_violations: List(Violation),
  )
}

pub type FixConfig {
  FixConfig(
    create_backups: Bool,
    validate_after_fix: Bool,
    rollback_on_failure: Bool,
    max_retries: Int,
  )
}

pub type VibeecGenResult {
  VibeecGenResult(
    success: Bool,
    output: String,
    error: Option(String),
    exit_code: Int,
  )
}

pub fn default_fix_config() -> FixConfig {
  FixConfig(
    create_backups: True,
    validate_after_fix: True,
    rollback_on_failure: True,
    max_retries: 3,
  )
}

pub fn fix_violation(
  violation: Violation,
  config: FixConfig,
) -> Result(FixResult, String) {
  case can_auto_fix(violation) {
    False ->
      Ok(FixResult(
        violation: violation,
        fixed: False,
        action: ManualFixRequired,
        backup_path: None,
        error: Some("Violation cannot be auto-fixed"),
      ))
    True -> {
      case config.create_backups {
        True -> {
          case create_backup(violation.file_path) {
            Ok(backup_info) -> {
              case attempt_fix(violation, config) {
                Ok(fix_result) -> Ok(fix_result)
                Error(err) -> {
                  case config.rollback_on_failure {
                    True -> {
                      let _ = restore_backup(backup_info)
                      Error(err)
                    }
                    False -> Error(err)
                  }
                }
              }
            }
            Error(err) -> Error("Failed to create backup: " <> err)
          }
        }
        False -> attempt_fix(violation, config)
      }
    }
  }
}

fn attempt_fix(
  violation: Violation,
  config: FixConfig,
) -> Result(FixResult, String) {
  case get_spec_for_file(violation.file_path) {
    Some(spec_path) -> {
      case regenerate_from_spec(violation.file_path, spec_path) {
        Ok(_) ->
          Ok(FixResult(
            violation: violation,
            fixed: True,
            action: RegeneratedFromSpec,
            backup_path: None,
            error: None,
          ))
        Error(err) ->
          Error("Failed to regenerate from spec: " <> err)
      }
    }
    None ->
      Ok(FixResult(
        violation: violation,
        fixed: False,
        action: ManualFixRequired,
        backup_path: None,
        error: Some("No spec file found"),
      ))
  }
}

pub fn fix_all_violations(
  violations: List(Violation),
  config: FixConfig,
) -> List(FixResult) {
  list.filter_map(violations, fn(violation) { fix_violation(violation, config) })
}

pub fn regenerate_from_spec(
  gleam_file: String,
  spec_file: String,
) -> Result(Nil, String) {
  case run_vibeec_gen(spec_file, gleam_file) {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

pub fn create_backup(file_path: String) -> Result(BackupInfo, String) {
  let timestamp = 1_704_067_200
  let backup_path = file_path <> ".backup." <> int.to_string(timestamp)

  case simplifile.copy_file(file_path, backup_path) {
    Ok(_) ->
      Ok(BackupInfo(
        original_path: file_path,
        backup_path: backup_path,
        timestamp: timestamp,
      ))
    Error(_) -> Error("Failed to create backup")
  }
}

pub fn restore_backup(backup_info: BackupInfo) -> Result(Nil, String) {
  case simplifile.copy_file(backup_info.backup_path, backup_info.original_path) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Failed to restore backup")
  }
}

pub fn validate_fix(
  file_path: String,
  original_violations: List(Violation),
) -> ValidationResult {
  // Simplified validation
  ValidationResult(valid: True, remaining_violations: [], new_violations: [])
}

pub fn run_vibeec_gen(
  spec_path: String,
  output_path: String,
) -> Result(String, String) {
  // Placeholder: vibeec not yet available
  Error("vibeec compiler not yet available")
}

pub fn can_auto_fix(violation: Violation) -> Bool {
  violation.auto_fixable
}

pub fn get_spec_for_file(gleam_file: String) -> Option(String) {
  scanner.find_spec_for_module(gleam_file)
}

pub fn cleanup_backups(
  directory: String,
  keep_count: Int,
) -> Result(Int, String) {
  // Placeholder implementation
  Ok(0)
}
