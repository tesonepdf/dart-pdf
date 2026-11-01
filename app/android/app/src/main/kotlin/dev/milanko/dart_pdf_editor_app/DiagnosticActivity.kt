package dev.milanko.dart_pdf_editor_app

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.TypedValue
import android.widget.ScrollView
import android.widget.TextView

/** Schermata di diagnostica: mostra cosa manda l'app che apre o condivide. */
class DiagnosticActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = TextView(this).apply {
            setTextIsSelectable(true)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(32, 48, 32, 48)
            this.text = describe(intent)
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }

    private fun describe(i: Intent): String {
        val sb = StringBuilder()
        fun line(k: String, v: Any?) { sb.append(k).append(": ").append(v ?: "-").append('\n') }
        line("Azione", i.action)
        line("Tipo", i.type)
        line("Indirizzo", i.dataString)
        line("Schema", i.scheme)
        line("Categorie", i.categories?.joinToString(", "))
        line("Pacchetto", i.`package`)
        line("Componente", i.component?.flattenToShortString())
        line("Flag", "0x" + Integer.toHexString(i.flags))
        line("Chiamante", try { referrer } catch (e: Throwable) { null })
        line("Chiamante (activity)", try { callingPackage } catch (e: Throwable) { null })
        sb.append("\n--- Extra ---\n")
        try {
            val ex = i.extras
            if (ex == null) sb.append("nessuno\n") else for (k in ex.keySet()) {
                val v = try { @Suppress("DEPRECATION") ex.get(k) } catch (e: Throwable) { "errore: $e" }
                line(k, v?.let { "${it.javaClass.simpleName} = $it" })
            }
        } catch (e: Throwable) {
            line("Errore extra", e)
        }
        sb.append("\n--- ClipData ---\n")
        val clip: ClipData? = i.clipData
        if (clip == null) sb.append("nessuna\n") else {
            line("Tipi", (0 until clip.description.mimeTypeCount).map { clip.description.getMimeType(it) }.joinToString(", "))
            for (n in 0 until clip.itemCount) {
                val it = clip.getItemAt(n)
                line("Elemento $n uri", it.uri)
                line("Elemento $n testo", it.text)
            }
        }
        sb.append("\n--- File ---\n")
        val uris = LinkedHashSet<Uri>()
        i.data?.let { uris.add(it) }
        try {
            @Suppress("DEPRECATION")
            (i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uris.add(it) }
            @Suppress("DEPRECATION")
            i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
        } catch (e: Throwable) { line("Errore stream", e) }
        if (clip != null) for (n in 0 until clip.itemCount) clip.getItemAt(n).uri?.let { uris.add(it) }
        if (uris.isEmpty()) sb.append("nessun file\n")
        for (u in uris) {
            line("Uri", u)
            try { line("  Tipo risolto", contentResolver.getType(u)) } catch (e: Throwable) { line("  Tipo risolto", "errore: $e") }
            try {
                contentResolver.query(u, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val si = c.getColumnIndex(OpenableColumns.SIZE)
                        if (ni >= 0) line("  Nome", c.getString(ni))
                        if (si >= 0) line("  Dimensione", c.getString(si))
                    }
                }
            } catch (e: Throwable) { line("  Nome/dimensione", "errore: $e") }
            try {
                contentResolver.openInputStream(u)?.use { s ->
                    val b = ByteArray(8)
                    val n = s.read(b)
                    line("  Primi byte", if (n > 0) String(b, 0, n, Charsets.ISO_8859_1).replace(Regex("[^\\x20-\\x7E]"), ".") else "vuoto")
                }
            } catch (e: Throwable) { line("  Lettura", "errore: $e") }
        }
        return sb.toString()
    }
}
