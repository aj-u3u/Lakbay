package com.lakbay.plus.lakbay_plus

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val createPdfRequestCode = 4017
    private var pendingPdf: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lakbay_plus/pdf_export")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("export_busy", "Finish the current PDF export first.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || bytes.isEmpty() || filename.isNullOrBlank()) {
                    result.error("invalid_pdf", "The PDF report is missing.", null)
                    return@setMethodCallHandler
                }
                pendingPdf = bytes
                pendingResult = result
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    startActivityForResult(intent, createPdfRequestCode)
                } catch (error: Exception) {
                    pendingPdf = null
                    pendingResult = null
                    result.error("save_unavailable", "Could not open a save location.", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createPdfRequestCode) return
        val result = pendingResult ?: return
        val bytes = pendingPdf
        pendingResult = null
        pendingPdf = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(data.data!!)?.use { output ->
                output.write(bytes ?: throw IllegalStateException("PDF data is missing"))
                output.flush()
            } ?: throw IllegalStateException("Cannot write to selected location")
            result.success(true)
        } catch (error: Exception) {
            result.error("save_failed", "Could not save the PDF report.", null)
        }
    }
}
