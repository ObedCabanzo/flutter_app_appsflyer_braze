package com.example.flutter_app_appsflyer_braze

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import com.appsflyer.AppsFlyerLib
import com.singular.flutter_sdk.SingularBridge;

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        SingularBridge.onNewIntent(intent);
    }
}