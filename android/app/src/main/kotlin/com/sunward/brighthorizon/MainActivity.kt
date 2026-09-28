package com.sunward.brighthorizon

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — WebView file-upload bridge + window policy
// ============================================================
// A site's <input type="file"> triggers the WebView's file selector, which
// the Dart side forwards over this MethodChannel; we open the system
// chooser and hand the picked content:// URIs straight back.
//
// This exists so the project does not depend on file_picker: its 10.x
// releases are Kotlin-only and collide with Flutter's bundled Kotlin
// support (gray_part_pitfalls.md §1).
//
// WINDOW POLICY (edge-to-edge, IME does not move the window)
// `setDecorFitsSystemWindows(false)` makes the window draw edge-to-edge
// and — crucially — stops the framework from resizing or panning the decor
// for the software keyboard. The IME arrives purely as a window inset,
// which Flutter's engine reports as `viewInsets.bottom` WITHOUT shrinking
// the Flutter surface. PortalStage reads that height and repositions the
// focused field inside the page itself, so the WebView never resizes when
// the keyboard opens or when the navigation bar is swiped in. Re-applied on
// configuration change because a rotation can reset the decor fitting.
// ============================================================
class MainActivity : FlutterActivity() {
    // Must stay identical to the MethodChannel name in
    // lib/relay/stage/portal_stage.dart. The literal is visible in both the
    // APK and the Dart snapshot, so it is rotated per project rather than
    // being a generic "app/files".
    private val channelName = "hzn/chooser"
    private val pickRequest = 0x5C31
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    openChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // The WebView blocks its file input until the previous request is
        // answered, so an abandoned one is resolved before starting another.
        pendingResult?.success(emptyList<String>())
        pendingResult = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pendingResult = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}
