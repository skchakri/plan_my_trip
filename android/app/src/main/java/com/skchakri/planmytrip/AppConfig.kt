package com.skchakri.planmytrip

object AppConfig {
    /**
     * The Rails dev server URL.
     * - Android emulator on the same Linux host: use `http://10.0.2.2:3010`
     *   (the special address that points to the host machine's `localhost`).
     * - Physical device on the same Wi-Fi: use the host's LAN IP, e.g.
     *   `http://192.168.1.42:3010`.
     */
    const val baseUrl: String = "http://10.0.2.2:3010"

    val rootUrl: String get() = baseUrl
    val pathConfigurationUrl: String get() = "$baseUrl/configurations/android.json"
}
