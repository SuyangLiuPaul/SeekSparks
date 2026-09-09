package com.example.yahwehswords

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // 2026-05-24 (v1.2.97): themed launcher icon variants. Each
    // alias is declared in AndroidManifest.xml and points at this
    // same activity. We enable exactly one alias (or the main
    // MainActivity component itself) at a time via
    // PackageManager.setComponentEnabledSetting.
    //
    // Aliases must be referenced by their full ComponentName
    // (PACKAGE/.AliasName) — Android won't accept relative names
    // here even though the manifest uses `.AliasRed`.
    private val pkg = "com.example.yahwehswords"
    private val aliasMap = mapOf(
        // Map alternate-icon name (sent by Dart) → component class
        // path. Null key = "primary icon" = the main MainActivity.
        "AppIcon-Red"    to "$pkg.AliasRed",
        "AppIcon-Orange" to "$pkg.AliasOrange",
        "AppIcon-Green"  to "$pkg.AliasGreen",
        "AppIcon-Purple" to "$pkg.AliasPurple",
        "AppIcon-Pink"   to "$pkg.AliasPink",
        "AppIcon-Dark"   to "$pkg.AliasDark",
    )
    private val mainComponent = "$pkg.MainActivity"

    // 2026-06-16 (v1.3.85): the launcher-icon swap MUST be deferred
    // until the app leaves the foreground.
    //
    // BUG it fixes: changing the theme colour made the Android app
    // "quit" the instant the colour changed. The swap disables the
    // component the running task is rooted on (MainActivity when
    // leaving the default blue, or the active alias when switching
    // between colours). Disabling that component makes Android FINISH
    // the task — `DONT_KILL_APP` only spares the *process*, not the
    // task whose root component you just disabled. So the foreground
    // activity was torn down out from under the user every time.
    //
    // FIX: record the desired icon and apply the actual
    // setComponentEnabledSetting swap in onStop(), i.e. once the
    // activity is no longer visible. A stopped activity instance is
    // kept warm by the system, so disabling its component there is
    // safe — the launcher shows the new icon by the time the user
    // returns, and the app is never killed. This matches how
    // production apps (Telegram et al.) do runtime icon switching.
    //
    // `pendingIconName` holds the alternate-icon key (or null =
    // revert to primary); `hasPendingIcon` distinguishes "queued a
    // revert-to-primary (null)" from "nothing queued".
    private var pendingIconName: String? = null
    private var hasPendingIcon = false

    // 2026-09-09 (review finding 4): the "install unknown apps"
    // request answers Dart only when the reader comes BACK from the
    // settings screen, not when it opens. Before this, `success(true)`
    // was sent the instant `startActivity` returned, so Dart could not
    // tell "the screen opened" from "they granted it", and the reader
    // returned to a dialog telling them to press a button that was no
    // longer on screen. The pending result is held here and completed
    // in `onActivityResult` with the switch's state at that moment.
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val requestUnknownSources = 0x5EEC

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yswords/android_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentIconName" -> {
                        // If a swap is queued but not yet applied (we apply on
                        // onStop), report the QUEUED choice so Dart's
                        // "already set → skip" guard stays consistent with what
                        // the user just picked. Otherwise read the live state:
                        // walk every alias; whichever is ENABLED is "current".
                        // If none, return null (= primary icon).
                        if (hasPendingIcon) {
                            result.success(pendingIconName)
                            return@setMethodCallHandler
                        }
                        val pm = applicationContext.packageManager
                        var found: String? = null
                        for ((iconName, klass) in aliasMap) {
                            val comp = ComponentName(pkg, klass)
                            val state = pm.getComponentEnabledSetting(comp)
                            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                                found = iconName
                                break
                            }
                        }
                        result.success(found)
                    }
                    "setIcon" -> {
                        val args = call.arguments as? Map<*, *>
                        val name = args?.get("name") as? String
                        // Do NOT apply now — disabling the rooted component
                        // while foreground tears the task down (see the field
                        // doc above). Queue it; onStop() applies it once the
                        // activity is backgrounded.
                        pendingIconName = name
                        hasPendingIcon = true
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2026-09-09: hand a downloaded APK to the system installer,
        // so "update" is a button in the app instead of a trip through
        // the browser and the Downloads folder.
        //
        // Three methods and no fourth, because there is no fourth
        // thing this side can honestly do. It cannot install silently
        // (only a device owner can), it cannot report progress (the
        // download happens in Dart), and it cannot tell whether the
        // reader went through with it (the installer is a separate
        // task and returns nothing to us — the app finds out the way
        // everyone else does, by being restarted as the new version).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yswords/apk_installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Below API 26 the permission is granted at install
                    // time and there is no per-app switch to check.
                    "canInstall" -> {
                        val allowed =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                packageManager.canRequestPackageInstalls()
                            } else {
                                true
                            }
                        result.success(allowed)
                    }
                    // 2026-09-09 (review finding 7): which package this
                    // build IS, so Dart can pick the release asset that
                    // updates it. The `.cn` flavour has a different
                    // applicationId; the international APK would be
                    // installed beside it as a second app, not over it.
                    "packageName" -> result.success(packageName)
                    // Opens the OS screen for THIS app specifically.
                    // Deliberately not a general Settings deep-link:
                    // the reader is one tap from the switch that
                    // matters, and lands back here by pressing Back.
                    //
                    // The reply is deferred to onActivityResult and
                    // says whether the switch is on NOW — see
                    // `pendingPermissionResult`. A second request
                    // while one is open gets the same deferred answer.
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (pendingPermissionResult != null) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            try {
                                pendingPermissionResult = result
                                startActivityForResult(
                                    Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:$packageName")
                                    ),
                                    requestUnknownSources
                                )
                            } catch (e: Exception) {
                                pendingPermissionResult = null
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    // Where Dart should write the download.
                    //
                    // Asked of this side rather than resolved with
                    // path_provider, and that is not dependency
                    // squeamishness: this directory has to be the one
                    // `res/xml/update_file_paths.xml` declares, or
                    // `FileProvider.getUriForFile` throws
                    // IllegalArgumentException at the last step of an
                    // update the reader has already waited for. One
                    // side owns the path; the other asks.
                    "updateDir" -> {
                        val dir = File(cacheDir, "updates")
                        dir.mkdirs()
                        result.success(dir.absolutePath)
                    }
                    "install" -> {
                        val path = (call.arguments as? Map<*, *>)
                            ?.get("path") as? String
                        if (path == null) {
                            result.error("no_path", "install needs a path", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("missing", "no file at $path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            // A `file://` URI would throw
                            // FileUriExposedException on API 24+; the
                            // provider is declared in the manifest
                            // against `${applicationId}.updates` so the
                            // `.cn` flavour does not collide with the
                            // international build on the same device.
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.updates",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(
                                    uri,
                                    "application/vnd.android.package-archive"
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestUnknownSources) return
        // The settings screen's own result code says nothing useful;
        // the switch is re-read instead, which is the only fact Dart
        // needs to decide whether to carry on with the install.
        val granted =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                packageManager.canRequestPackageInstalls()
            } else {
                true
            }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    override fun onStop() {
        super.onStop()
        // Apply any queued launcher-icon swap now that the activity is no
        // longer visible — safe to disable the (now backgrounded) rooted
        // component here without killing the app.
        if (hasPendingIcon) {
            applyIcon(pendingIconName)
            hasPendingIcon = false
        }
    }

    /// Enable the target alias (or the primary MainActivity when
    /// [name] is null) and disable every other launcher component so
    /// exactly one icon shows. Best-effort: PackageManager can throw
    /// on locked-down OEM ROMs; there is nothing actionable to do but
    /// swallow it so a backgrounding never crashes.
    private fun applyIcon(name: String?) {
        val pm = applicationContext.packageManager
        val targetAlias: String? = name?.let { aliasMap[it] }
        try {
            if (targetAlias != null) {
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, targetAlias),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                // Disable the primary (so two icons don't show).
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, mainComponent),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            } else {
                // Reverting to primary: enable MainActivity; the loop
                // below disables every alias.
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, mainComponent),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
            // Disable every OTHER alias (and the primary if we just
            // enabled an alias above).
            for ((_, klass) in aliasMap) {
                if (klass == targetAlias) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, klass),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } catch (e: Exception) {
            // Best-effort; nothing else we can do at backgrounding time.
        }
    }
}
