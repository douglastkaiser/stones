package com.douglastkaiser.stones

import android.app.Application
import com.google.android.gms.games.PlayGamesSdk

class StonesApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Firebase accounts work independently of optional Play Games setup.
        if (getString(R.string.play_games_app_id) != "0") {
            PlayGamesSdk.initialize(this)
        }
    }
}
