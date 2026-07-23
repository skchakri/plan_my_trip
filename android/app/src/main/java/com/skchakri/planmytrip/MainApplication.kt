package com.skchakri.planmytrip

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.registerBridgeComponents

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.config.applicationUserAgentPrefix = "Hotwire Native Android"

        // Registering the component is what puts "speech" in the user agent;
        // the web side's BridgeComponent only loads when it sees it there.
        // Without this the WebView has no speech at all — it implements
        // neither speechSynthesis nor SpeechRecognition.
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("speech", ::SpeechComponent)
        )

        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                remoteFileUrl = AppConfig.pathConfigurationUrl
            )
        )
    }
}
