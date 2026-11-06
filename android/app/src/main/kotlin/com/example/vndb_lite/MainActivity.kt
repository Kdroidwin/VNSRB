package com.vndblite.dcj

import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
    }

    @Suppress("DEPRECATION")
    private fun requestHighestRefreshRate() {
        val refreshRate = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.supportedModes?.maxByOrNull { it.refreshRate }?.refreshRate
        } else {
            windowManager.defaultDisplay.refreshRate
        } ?: return

        val attributes = window.attributes
        if (attributes.preferredRefreshRate != refreshRate) {
            attributes.preferredRefreshRate = refreshRate
            window.attributes = attributes
        }
    }
}
