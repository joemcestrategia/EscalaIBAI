package com.escalaibai.escala_ibai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import android.view.View
import android.content.SharedPreferences

class EscalaWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.escala_widget).apply {
                val jsonString = widgetData.getString("escalas_data", "[]")
                val currentIndex = widgetData.getInt("current_escala_index", 0)

                try {
                    val jsonArray = JSONArray(jsonString)
                    val totalDias = jsonArray.length()

                    if (totalDias > 0) {
                        val validIndex = if (currentIndex in 0 until totalDias) currentIndex else 0
                        val item = jsonArray.getJSONObject(validIndex)
                        
                        val dataStr = item.getString("data")
                        val dataParts = dataStr.split("-")
                        val dataFormatada = if (dataParts.size == 3) "${dataParts[2]}/${dataParts[1]}" else dataStr
                        val diaSemana = item.getString("dia_semana").take(3).replaceFirstChar { it.uppercase() }
                        
                        setTextViewText(R.id.tv_date, "$diaSemana, $dataFormatada - ${item.getString("horario")}")
                        setTextViewText(R.id.tv_tema, item.getString("tema"))
                        setTextViewText(R.id.tv_indicator, "${validIndex + 1}/$totalDias")

                        setViewVisibility(R.id.layout_content, View.VISIBLE)
                        setViewVisibility(R.id.tv_empty, View.GONE)
                        
                        // Limpar as views anteriores da lista
                        removeAllViews(R.id.layout_lista_pessoas)
                        
                        val ministeriosArray = item.optJSONArray("ministerios") ?: JSONArray()
                        for (i in 0 until ministeriosArray.length()) {
                            val minObj = ministeriosArray.getJSONObject(i)
                            val nomeMin = minObj.optString("nome_min", "")
                            val pessoasHtml = minObj.optString("pessoas", "")
                            
                            val parsedHtml = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                                android.text.Html.fromHtml(pessoasHtml, android.text.Html.FROM_HTML_MODE_COMPACT)
                            } else {
                                @Suppress("DEPRECATION")
                                android.text.Html.fromHtml(pessoasHtml)
                            }
                            
                            val itemView = RemoteViews(context.packageName, R.layout.escala_widget_item)
                            itemView.setTextViewText(R.id.tv_item_ministerio, nomeMin)
                            itemView.setTextViewText(R.id.tv_item_nome_funcao, parsedHtml)
                            
                            addView(R.id.layout_lista_pessoas, itemView)
                        }
                        
                        // Configurar o clique no layout para abrir o App
                        val openAppIntent = Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        val openAppPendingIntent = PendingIntent.getActivity(
                            context, 0, openAppIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.layout_content, openAppPendingIntent)
                        
                        val prevIntent = Intent(context, EscalaWidgetProvider::class.java).apply { action = "ACTION_PREV" }
                        val prevPendingIntent = PendingIntent.getBroadcast(context, 1, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        setOnClickPendingIntent(R.id.btn_prev, prevPendingIntent)
                        
                        val nextIntent = Intent(context, EscalaWidgetProvider::class.java).apply { action = "ACTION_NEXT" }
                        val nextPendingIntent = PendingIntent.getBroadcast(context, 2, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        setOnClickPendingIntent(R.id.btn_next, nextPendingIntent)
                        
                    } else {
                        setViewVisibility(R.id.layout_content, View.GONE)
                        setViewVisibility(R.id.tv_empty, View.VISIBLE)
                    }
                } catch (e: Exception) {
                    setViewVisibility(R.id.layout_content, View.GONE)
                    setViewVisibility(R.id.tv_empty, View.VISIBLE)
                    setTextViewText(R.id.tv_empty, "Nenhuma escala futura.")
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == "ACTION_NEXT" || intent.action == "ACTION_PREV") {
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonString = widgetData.getString("escalas_data", "[]")
            var currentIndex = widgetData.getInt("current_escala_index", 0)
            
            try {
                val totalDias = JSONArray(jsonString).length()
                if (totalDias > 0) {
                    if (intent.action == "ACTION_NEXT") {
                        currentIndex = (currentIndex + 1) % totalDias
                    } else {
                        currentIndex = (currentIndex - 1 + totalDias) % totalDias
                    }
                    
                    widgetData.edit().putInt("current_escala_index", currentIndex).apply()
                    
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val componentName = android.content.ComponentName(context, EscalaWidgetProvider::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                    onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}
