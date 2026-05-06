package com.skchakri.planmytrip

import android.app.Application
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.navigation.routing.AppNavHostFragment
import dev.hotwire.navigation.fragments.HotwireWebFragment

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.config.applicationUserAgentPrefix = "Hotwire Native Android"
        Hotwire.loadPathConfiguration(
            context = this,
            location = AppConfig.pathConfigurationUrl
        )

        // Map the URIs declared in /configurations/android.json to fragments
        Hotwire.registerFragmentDestinations(
            HotwireWebFragment::class
        )
    }
}
