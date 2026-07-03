package com.skchakri.planmytrip

object AppConfig {
    /**
     * The server the shell wraps. Defaults to production.
     * For local development against the Rails dev server:
     * - Physical device over USB: `http://localhost:3010` + `adb reverse tcp:3010 tcp:3010`
     *   (the device then sees the host's dev server as its own localhost).
     * - Android emulator on the same Linux host: `http://10.0.2.2:3010`.
     * - Physical device on the same Wi-Fi: the host's LAN IP, e.g. `http://192.168.1.42:3010`.
     */
    const val baseUrl: String = "https://wanderply.com"

    val rootUrl: String get() = baseUrl
    val pathConfigurationUrl: String get() = "$baseUrl/configurations/android.json"
}
