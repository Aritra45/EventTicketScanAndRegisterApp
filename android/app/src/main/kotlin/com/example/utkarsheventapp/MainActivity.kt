package com.utkarsh.utkarsheventapp

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.utkarsh.utkarsheventapp/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareToWhatsApp" -> {
                    val phone = call.argument<String>("phone")
                    val imagePath = call.argument<String>("imagePath")
                    val text = call.argument<String>("text") ?: ""

                    try {
                        if (phone == null || imagePath == null) {
                            result.error("INVALID_ARGUMENT", "Phone or ImagePath is null", null)
                            return@setMethodCallHandler
                        }

                        val sanitizedPhone = phone.replace("+", "").replace(" ", "")
                        val jid = "$sanitizedPhone@s.whatsapp.net"

                        val file = File(imagePath)
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )

                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "image/*"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_TEXT, text)
                            putExtra("jid", jid)
                            setPackage("com.whatsapp")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }

                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_SHARE_ERROR", e.message, null)
                    }
                }

                "openWhatsAppChat" -> {
                    val phone = call.argument<String>("phone")
                    val text = call.argument<String>("text") ?: ""

                    try {
                        if (phone == null) {
                            result.error("INVALID_ARGUMENT", "Phone is null", null)
                            return@setMethodCallHandler
                        }

                        val sanitizedPhone = phone.replace("+", "").replace(" ", "")
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse("https://wa.me/$sanitizedPhone?text=${Uri.encode(text)}")
                            setPackage("com.whatsapp")
                        }

                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_OPEN_CHAT_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
