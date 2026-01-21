// VIBEE Browser - Tauri 2 Backend
// φ² + 1/φ² = 3 | PHOENIX = 999

#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use tauri::Manager;

const PHI: f64 = 1.618033988749895;
const VERSION: &str = "2482.0.0";

#[tauri::command]
fn get_phi() -> serde_json::Value {
    let phi_sq = PHI * PHI;
    let phi_inv_sq = 1.0 / phi_sq;
    let trinity = phi_sq + phi_inv_sq;
    
    serde_json::json!({
        "phi": PHI,
        "phi_squared": phi_sq,
        "phi_inv_squared": phi_inv_sq,
        "trinity": trinity,
        "phoenix": 999
    })
}

#[tauri::command]
fn get_version() -> String {
    VERSION.to_string()
}

#[tauri::command]
fn eval_ternary(expr: String) -> serde_json::Value {
    let result = if expr.contains("AND") {
        if expr.contains("unknown") || expr.contains("0") {
            ("unknown", 0)
        } else if expr.contains("false") || expr.contains("-1") {
            ("false", -1)
        } else {
            ("true", 1)
        }
    } else if expr.contains("OR") {
        if expr.contains("true") || expr.contains("1") {
            ("true", 1)
        } else if expr.contains("unknown") || expr.contains("0") {
            ("unknown", 0)
        } else {
            ("false", -1)
        }
    } else {
        ("unknown", 0)
    };
    
    serde_json::json!({
        "expression": expr,
        "result": result.0,
        "value": result.1
    })
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();
            window.set_title("VIBEE Browser - φ² + 1/φ² = 3 | PHOENIX = 999").unwrap();
            
            println!("╔═══════════════════════════════════════════════════════════════╗");
            println!("║  VIBEE Browser v{}                                      ║", VERSION);
            println!("║  Ternary Logic AI Browser                                     ║");
            println!("║  φ² + 1/φ² = 3 | PHOENIX = 999                                ║");
            println!("╚═══════════════════════════════════════════════════════════════╝");
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_phi,
            get_version,
            eval_ternary
        ])
        .run(tauri::generate_context!())
        .expect("error while running VIBEE Browser");
}
