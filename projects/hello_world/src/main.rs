//! A greeting that carries the identity of the image it was built into.
//!
//! The example touches no peripheral: it boots, states which crate version, which
//! chip target and which ESP-IDF it was built against, greets once, and returns
//! from `app_main`. That is enough to prove a downloaded image runs on a board you
//! did not build it on.

use std::ffi::CStr;

fn main() {
    // Patches the runtime esp-idf-sys links in. Must run once, before anything else.
    esp_idf_svc::sys::link_patches();

    // Routes `log::info!` through the ESP-IDF logger, which writes to the UART console.
    esp_idf_svc::log::EspLogger::initialize_default();

    // The IDF version string comes from the IDF tree this image was compiled against.
    let idf_version = unsafe { CStr::from_ptr(esp_idf_svc::sys::esp_get_idf_version()) };

    log::info!(
        "hello_world {} targeting {}",
        env!("CARGO_PKG_VERSION"),
        env!("MCU")
    );
    log::info!("built against ESP-IDF {}", idf_version.to_string_lossy());
    log::info!("Hello, world!");
}
