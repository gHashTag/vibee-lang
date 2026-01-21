// VIBEE Browser - Tauri 2 with Multi-Window Navigation
// φ² + 1/φ² = 3 | PHOENIX = 999

#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use tauri::{Manager, WebviewUrl, WebviewWindowBuilder};

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
async fn open_url(url: String, app: tauri::AppHandle) -> Result<(), String> {
    // Open URL in a new browser window
    let window_id = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis();
    
    let label = format!("browser_{}", window_id);
    
    let parsed_url: url::Url = url.parse()
        .map_err(|e| format!("Invalid URL: {}", e))?;
    
    WebviewWindowBuilder::new(
        &app,
        &label,
        WebviewUrl::External(parsed_url)
    )
    .title(format!("VIBEE - {}", url))
    .inner_size(1280.0, 900.0)
    .center()
    .build()
    .map_err(|e| format!("Failed to open: {}", e))?;
    
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();
            window.set_title("VIBEE Browser - φ² + 1/φ² = 3").unwrap();
            
            println!("╔═══════════════════════════════════════════════════════════════╗");
            println!("║  VIBEE Browser v{}                                      ║", VERSION);
            println!("║  φ² + 1/φ² = 3 | PHOENIX = 999                                ║");
            println!("╚═══════════════════════════════════════════════════════════════╝");
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_phi,
            get_version,
            open_url
        ])
        .run(tauri::generate_context!())
        .expect("error while running VIBEE Browser");
}
