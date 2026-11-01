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
        line("Intent completo", try { i.toUri(0) } catch (e: Throwable) { null })
        sb.append("\n--- Ambiente ---\n")
        line("Company Portal", installed("com.microsoft.windowsintune.companyportal"))
        line("Outlook", installed("com.microsoft.office.outlook"))
        line("Profilo di lavoro", try { getSystemService(android.os.UserManager::class.java).isManagedProfile } catch (e: Throwable) { null })
        sb.append("\n--- App che aprono questo file (VIEW) ---\n")
        handlers(i, Intent.ACTION_VIEW, sb)
        sb.append("\n--- App che ricevono questo file (SEND) ---\n")
        handlers(i, Intent.ACTION_SEND, sb)
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

    private fun fileUri(i: Intent): Uri? = try {
        i.data ?: @Suppress("DEPRECATION") i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            ?: i.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
    } catch (e: Throwable) { null }

    private fun handlers(i: Intent, action: String, sb: StringBuilder) {
        try {
            val uri = fileUri(i)
            val type = i.type ?: uri?.let { contentResolver.getType(it) } ?: "application/pdf"
            val probe = Intent(action)
            if (action == Intent.ACTION_VIEW) probe.setDataAndType(uri, type) else probe.setType(type)
            sb.append("Richiesta: ").append(action.substringAfterLast('.')).append(" tipo ").append(type).append('\n')
            val list = packageManager.queryIntentActivities(probe, 0)
            if (list.isEmpty()) sb.append("nessuna\n")
            for (r in list) {
                val me = if (r.activityInfo.packageName == packageName) "  <-- DartPDF" else ""
                sb.append(r.activityInfo.packageName).append(" / ").append(r.activityInfo.name.substringAfterLast('.')).append(me).append('\n')
                if (action == Intent.ACTION_VIEW) sb.append("   ").append(details(r)).append('\n')
            }
        } catch (e: Throwable) { sb.append("errore: ").append(e).append('\n') }
    }

    private fun installed(pkg: String): String = try {
        val pi = packageManager.getPackageInfo(pkg, 0)
        "si (" + pi.versionName + ")"
    } catch (e: Throwable) { "no/non visibile" }

    private fun details(r: android.content.pm.ResolveInfo): String {
        val sb = StringBuilder()
        try {
            val f = r.filter
            if (f != null) {
                sb.append("schemi=").append((0 until f.countDataSchemes()).joinToString(",") { f.getDataScheme(it) })
                sb.append(" tipi=").append((0 until f.countDataTypes()).joinToString(",") { f.getDataType(it) })
                sb.append(" cat=").append(f.categoriesIterator()?.asSequence()?.joinToString(",") { it.substringAfterLast('.') })
                sb.append(" path=").append(f.countDataPaths())
            }
            sb.append(" prio=").append(r.priority)
            sb.append(" esportata=").append(r.activityInfo.exported)
        } catch (e: Throwable) { sb.append("errore filtro: ").append(e) }
        try {
            @Suppress("DEPRECATION")
            val pi = packageManager.getPackageInfo(
                r.activityInfo.packageName,
                android.content.pm.PackageManager.GET_ACTIVITIES or android.content.pm.PackageManager.GET_SERVICES or
                    android.content.pm.PackageManager.GET_RECEIVERS or android.content.pm.PackageManager.GET_PROVIDERS)
            val names = (pi.activities.orEmpty().map { it.name } + pi.services.orEmpty().map { it.name } +
                pi.receivers.orEmpty().map { it.name } + pi.providers.orEmpty().map { it.name })
            val mam = names.any { it.contains("intune", true) || it.contains(".mam.", true) || it.contains("MAM") }
            sb.append(" intune=").append(if (mam) "si" else "no")
        } catch (e: Throwable) { sb.append(" intune=?") }
        return sb.toString()
    }
}
