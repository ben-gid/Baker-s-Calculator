package dev.bengid.bakersCalculator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * The home-screen widget: the step a bake is on, with Done and 15 more min,
 * or the recipe pinned to it when no bake is running.
 *
 * Dart hands over the bake's whole forecast (`bakeSnapshot`), so the step
 * under way is picked here, at draw time: the first whose end is still ahead.
 * Dart also schedules a redraw at every step's end. The buttons go back to
 * Dart as `bakerscalc://widget/press` links; taps open the app on a route.
 */
class BakeWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val views = render(context, widgetData)
    for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
  }

  private fun render(context: Context, data: SharedPreferences): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.bake_widget)
    val now = System.currentTimeMillis()
    val bake = data.getString("bake", null)?.let(::JSONObject)
    val pinned = data.getString("pinned", null)?.let(::JSONObject)

    views.setViewVisibility(R.id.widget_timer, View.GONE)
    views.setViewVisibility(R.id.widget_primary, View.GONE)
    views.setViewVisibility(R.id.widget_secondary, View.GONE)

    if (bake != null) {
      val plan = "recipe/${bake.getString("recipeId")}/plan" +
          (if (bake.isNull("loaves")) "" else "?loaves=${bake.getInt("loaves")}")
      views.setTextViewText(R.id.widget_label, bake.getString("recipeName"))
      views.setOnClickPendingIntent(R.id.widget_root, open(context, plan))

      val steps = bake.getJSONArray("steps")
      val step = (0 until steps.length()).map(steps::getJSONObject)
          .firstOrNull { it.getLong("endsAt") > now }
      if (step == null) {
        views.setTextViewText(R.id.widget_title, "Bake finished")
        views.setTextViewText(R.id.widget_detail, "Every step is behind you.")
        return views
      }

      val index = step.getInt("step")
      val fold = step.optString("sets").takeIf { step.has("sets") }
      views.setTextViewText(R.id.widget_title, step.getString("title"))
      views.setChronometer(
          R.id.widget_timer,
          SystemClock.elapsedRealtime() + (step.getLong("endsAt") - now),
          "%s left",
          true,
      )
      views.setViewVisibility(R.id.widget_timer, View.VISIBLE)
      val next = if (step.isNull("next")) "Last step" else "Then: ${step.getString("next")}"
      views.setTextViewText(R.id.widget_detail, listOfNotNull(fold, next).joinToString(" · "))

      button(views, R.id.widget_primary, if (fold != null) "Set done" else "Done",
          press(context, "done", index))
      if (fold == null) {
        button(views, R.id.widget_secondary, "15 more min", press(context, "extend", index))
      }
      return views
    }

    if (pinned != null) {
      val id = pinned.getString("id")
      views.setTextViewText(R.id.widget_label, "Pinned recipe")
      views.setTextViewText(R.id.widget_title, pinned.getString("name"))
      views.setTextViewText(R.id.widget_detail, pinned.getString("line"))
      views.setOnClickPendingIntent(R.id.widget_root, open(context, "recipe/$id"))
      button(views, R.id.widget_primary, "Plan a bake", open(context, "recipe/$id/plan"))
      return views
    }

    views.setTextViewText(R.id.widget_label, "Baker's Calculator")
    views.setTextViewText(R.id.widget_title, "No bake running")
    views.setTextViewText(R.id.widget_detail, "Pin a recipe from its page to keep it here.")
    views.setOnClickPendingIntent(R.id.widget_root, open(context, ""))
    return views
  }

  private fun button(views: RemoteViews, id: Int, text: String, intent: PendingIntent) {
    views.setTextViewText(id, text)
    views.setViewVisibility(id, View.VISIBLE)
    views.setOnClickPendingIntent(id, intent)
  }

  /** A press handled by Dart in the background, as a reminder's button is. */
  private fun press(context: Context, action: String, step: Int) =
      HomeWidgetBackgroundIntent.getBroadcast(
          context, Uri.parse("bakerscalc://widget/press?action=$action&step=$step"))

  /** Opens the app on [route], which Flutter's deep linking hands to the router. */
  private fun open(context: Context, route: String): PendingIntent {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("bakerscalc://widget/$route"),
        context, MainActivity::class.java)
    return PendingIntent.getActivity(context, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  }
}
