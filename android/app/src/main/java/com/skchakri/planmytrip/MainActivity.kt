package com.skchakri.planmytrip

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {

    // Result is ignored: SpeechComponent re-checks the permission on every
    // listen and replies "not-allowed" if it was refused, which the web side
    // already renders as "Microphone blocked".
    private val requestMic =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        requestMicPermissionIfNeeded()
    }

    /**
     * The WebView can't prompt for the mic itself — SpeechComponent uses the
     * platform recognizer, so the permission has to come from the Activity.
     * Asked once at launch; Android shows nothing on later runs.
     */
    private fun requestMicPermissionIfNeeded() {
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) requestMic.launch(Manifest.permission.RECORD_AUDIO)
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        return listOf(
            NavigatorConfiguration(
                name = "main",
                startLocation = AppConfig.rootUrl,
                navigatorHostId = R.id.main_nav_host
            )
        )
    }
}
