package com.skchakri.planmytrip

import android.app.Application
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.config.applicationUserAgentPrefix = "Hotwire Native Android"

        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                remoteFileUrl = AppConfig.pathConfigurationUrl
            )
        )
    }
}
