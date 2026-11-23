package com.example.audioshare

import android.app.Activity
import android.app.Dialog
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.text.Editable
import android.text.TextUtils
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import io.flutter.plugin.common.MethodChannel

/** Selector de la app cuyo audio se comparte. Solo lista apps que Android permite capturar. */
object AppPickerDialog {
    private class Entry(val label: String, val uid: Int, val icon: Drawable)
    private class RowHolder(val icon: ImageView, val label: TextView)

    private val MEDIA_CATEGORIES = setOf(
        ApplicationInfo.CATEGORY_AUDIO,
        ApplicationInfo.CATEGORY_VIDEO,
        ApplicationInfo.CATEGORY_GAME,
    )

    fun show(activity: Activity, result: MethodChannel.Result) {
        val apps = loadApps(activity)
        if (apps.isEmpty()) {
            result.error("no-apps", "No encontré aplicaciones que permitan compartir su audio.", null)
            return
        }

        val density = activity.resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val night = (activity.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val surface = (if (night) 0xFF1F232B else 0xFFFFFFFF).toInt()
        val onSurface = (if (night) 0xFFF1F3F7 else 0xFF1B1D22).toInt()
        val muted = (if (night) 0xFF9AA3B2 else 0xFF667085).toInt()
        val field = (if (night) 0xFF2B303A else 0xFFF1F3F6).toInt()

        val dialog = Dialog(activity)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)

        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(22), dp(20), dp(8))
            background = GradientDrawable().apply {
                setColor(surface)
                val r = dp(24).toFloat()
                cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
            }
        }

        val title = TextView(activity).apply {
            text = "¿De qué app quieres compartir el audio?"
            setTextColor(onSurface)
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
        }
        val subtitle = TextView(activity).apply {
            text = "Solo se transmitirá el audio de la app que elijas."
            setTextColor(muted)
            textSize = 14f
            setPadding(0, dp(4), 0, dp(14))
        }
        val search = EditText(activity).apply {
            hint = "Buscar aplicación"
            setHintTextColor(muted)
            setTextColor(onSurface)
            textSize = 16f
            isSingleLine = true
            setPadding(dp(16), dp(12), dp(16), dp(12))
            background = GradientDrawable().apply {
                setColor(field)
                cornerRadius = dp(14).toFloat()
            }
        }
        val empty = TextView(activity).apply {
            text = "Ninguna aplicación coincide con tu búsqueda."
            setTextColor(muted)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, dp(24))
            visibility = View.GONE
        }

        val shown = ArrayList<Entry>(apps)
        val listAdapter = object : BaseAdapter() {
            override fun getCount() = shown.size
            override fun getItem(position: Int): Any = shown[position]
            override fun getItemId(position: Int) = position.toLong()
            override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
                val row: LinearLayout
                val holder: RowHolder
                if (convertView == null) {
                    val icon = ImageView(activity).apply {
                        layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
                    }
                    val label = TextView(activity).apply {
                        setTextColor(onSurface)
                        textSize = 16f
                        maxLines = 1
                        ellipsize = TextUtils.TruncateAt.END
                        layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                            .apply { leftMargin = dp(16) }
                    }
                    holder = RowHolder(icon, label)
                    row = LinearLayout(activity).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.CENTER_VERTICAL
                        setPadding(dp(8), dp(10), dp(8), dp(10))
                        addView(icon)
                        addView(label)
                        tag = holder
                    }
                } else {
                    row = convertView as LinearLayout
                    holder = row.tag as RowHolder
                }
                val entry = shown[position]
                holder.icon.setImageDrawable(entry.icon)
                holder.label.text = entry.label
                return row
            }
        }

        var picked = false
        val list = ListView(activity).apply {
            this.adapter = listAdapter
            divider = null
            dividerHeight = 0
            isVerticalScrollBarEnabled = false
            setOnItemClickListener { _, _, position, _ ->
                val entry = shown[position]
                picked = true
                result.success(mapOf("uid" to entry.uid, "label" to entry.label))
                dialog.dismiss()
            }
        }

        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val query = s?.toString()?.trim()?.lowercase().orEmpty()
                shown.clear()
                shown.addAll(if (query.isEmpty()) apps else apps.filter { it.label.lowercase().contains(query) })
                listAdapter.notifyDataSetChanged()
                empty.visibility = if (shown.isEmpty()) View.VISIBLE else View.GONE
            }
        })

        val cancel = TextView(activity).apply {
            text = "Cancelar"
            setTextColor(onSurface)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(14), 0, dp(14))
            setOnClickListener { dialog.dismiss() }
        }

        root.addView(title)
        root.addView(subtitle)
        root.addView(
            search,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                .apply { bottomMargin = dp(8) },
        )
        root.addView(empty)
        root.addView(list, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(cancel)

        dialog.setContentView(root)
        dialog.setCanceledOnTouchOutside(true)
        dialog.setOnDismissListener {
            if (!picked) result.error("cancelled", "No elegiste ninguna aplicación.", null)
        }
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (activity.resources.displayMetrics.heightPixels * 0.78).toInt(),
            )
            setGravity(Gravity.BOTTOM)
            setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
            attributes.windowAnimations = android.R.style.Animation_InputMethod
        }
        dialog.show()
    }

    private fun loadApps(activity: Activity): List<Entry> {
        val pm = activity.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { canBeCaptured(it, activity.packageName) }
            .map { Entry(it.loadLabel(pm).toString(), it.uid, it.loadIcon(pm)) }
            .sortedBy { it.label.lowercase() }
    }

    private fun canBeCaptured(info: ApplicationInfo, ownPackage: String): Boolean {
        if (info.packageName == ownPackage) return false
        // Android solo captura el audio de apps que apuntan a Android 10 (API 29) o más.
        if (info.targetSdkVersion < Build.VERSION_CODES.Q) return false
        val isSystem = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        val wasUpdated = (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        if (isSystem && !wasUpdated) {
            // Ajustes, Asistente, Ayuda del dispositivo...: fuera, salvo reproductores y juegos.
            return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && info.category in MEDIA_CATEGORIES
        }
        return true
    }
}