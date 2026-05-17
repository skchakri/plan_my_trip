package com.skchakri.planmytrip

object AppConfig {
    /**
     * The Rails dev server URL.
     * - Android emulator on the same Linux host: use `http://10.0.2.2:3010`
     *   (the special address that points to the host machine's `localhost`).
     * - Physical device on the same Wi-Fi: use the host's LAN IP, e.g.
     *   `http://192.168.1.42:3010`.
     */
    // Default to localhost for physical devices via `adb reverse tcp:3010 tcp:3010`
    // (so the device sees the host's Rails dev server as its own localhost). For
    // an emulator, switch to `http://10.0.2.2:3010`.
    const val baseUrl: String = "http://localhost:3010"

    val rootUrl: String get() = baseUrl
    val pathConfigurationUrl: String get() = "$baseUrl/configurations/android.json"
}
