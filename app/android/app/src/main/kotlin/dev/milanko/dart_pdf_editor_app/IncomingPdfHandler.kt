package dev.milanko.dart_pdf_editor_app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns

/** Reads a granted URI, never a guessed filesystem path or a writable origin. */
internal class IncomingPdfHandler {
    private var pending: Map<String, Any>? = null
    private var pendingBatch: List<Map<String, Any>>? = null

    fun takeInitialFile(): Map<String, Any>? = pending.also { pending = null }

    /** Everything the activity was launched with, as one batch (empty for none). */
    fun takeInitialFiles(): List<Map<String, Any>> {
        val batch = pendingBatch ?: listOfNotNull(pending)
        pendingBatch = null
        pending = null
        return batch
    }

    fun handle(
        intent: Intent?,
        initial: Boolean,
        resolver: ContentResolver,
        deliver: (Map<String, Any>) -> Unit,
    ) {
        val uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data ?: firstClipUri(intent)
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                stream ?: firstClipUri(intent)
            }
            else -> null
        } ?: return
        val payload = readPayload(uri, intent, resolver) ?: return
        // Copy during the temporary read grant; no persistable/storage permission
        // is required. Dart caches the bytes for recents and uses Save As.
        if (initial) pending = payload else deliver(payload)
    }

    /**
     * Several files shared together (ACTION_SEND_MULTIPLE, e.g. a few photos
     * picked in the gallery). All of them are read during the temporary grant
     * and handed over as one batch, so the Dart side can put them on one sheet.
     */
    fun handleMultiple(
        intent: Intent?,
        initial: Boolean,
        resolver: ContentResolver,
        deliver: (List<Map<String, Any>>) -> Unit,
    ) {
        if (intent?.action != Intent.ACTION_SEND_MULTIPLE) return
        val payloads = streamUris(intent).mapIndexedNotNull { index, uri ->
            readPayload(uri, intent, resolver, fallbackName = "foto-${index + 1}.jpg")
        }
        if (payloads.isEmpty()) return
        if (initial) pendingBatch = payloads else deliver(payloads)
    }

    /** Reads one granted URI into the payload the Dart side expects, or null. */
    private fun readPayload(
        uri: Uri,
        intent: Intent?,
        resolver: ContentResolver,
        fallbackName: String? = null,
    ): Map<String, Any>? {
        // Do not turn an externally supplied URI into a network request.
        if (uri.scheme != "content" && uri.scheme != "file") return null
        val bytes = try {
            resolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        } catch (_: Exception) {
            return null
        }
        // DISPLAY_NAME is optional. A provider may supply readable bytes while
        // refusing metadata queries (or omit this column altogether).
        val name = try {
            if (uri.scheme == "file") uri.lastPathSegment else {
                resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { cursor ->
                        val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
                    }
            }
        } catch (_: Exception) {
            null
        }
        // Se il provider non da' il nome (succede con Outlook e altre app),
        // si prova con il titolo/oggetto della condivisione e con l'ultimo
        // pezzo dell'indirizzo, prima di ripiegare su "document.pdf".
        // Con piu' file il titolo e' lo stesso per tutti: non lo si usa.
        val extraName = if (fallbackName != null) null else
            listOf(Intent.EXTRA_TITLE, Intent.EXTRA_SUBJECT)
                .mapNotNull { intent?.getStringExtra(it)?.trim() }
                .firstOrNull { it.isNotEmpty() }
        val pathName = uri.lastPathSegment?.substringAfterLast('/')
            ?.takeIf {
                val n = it.lowercase()
                n.endsWith(".pdf") || n.endsWith(".md") || n.endsWith(".markdown")
            }
        val finalName = name?.takeIf { it.isNotBlank() }
            ?: pathName
            ?: extraName
            ?: fallbackName
            ?: "document.pdf"
        return mapOf("name" to finalName, "bytes" to bytes)
    }

    private fun streamUris(intent: Intent): List<Uri> {
        @Suppress("DEPRECATION")
        val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        if (!streams.isNullOrEmpty()) return streams.filterNotNull()
        val clip = intent.clipData ?: return emptyList()
        return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
    }

    private fun firstClipUri(intent: Intent): Uri? = intent.clipData?.let {
        if (it.itemCount > 0) it.getItemAt(0).uri else null
    }
}
