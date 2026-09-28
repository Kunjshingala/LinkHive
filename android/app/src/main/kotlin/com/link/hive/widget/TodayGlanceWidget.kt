package com.link.hive.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.link.hive.MainActivity
import com.link.hive.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity

/**
 * Deep-link scheme the Dart side (HomeWidgetService) reads back via
 * HomeWidget.widgetClicked / initiallyLaunchedFromHomeWidget.
 */
private const val SCHEME = "linkhive"

/**
 * Colors are resource-backed on purpose.
 *
 * Glance 1.2.0 has exactly two ColorProvider factories — one taking a fixed
 * Color, one taking a color resource id. There is no day/night overload
 * (checked against the shipped bytecode, not from memory). The resource form
 * is the supported way to get a theme-dependent color: Glance's translator
 * emits a day/night ColorStateList for it, so values/ and values-night/ are
 * both honoured.
 *
 * What is NOT automatic is redrawing when the system theme flips — Android
 * doesn't re-render a placed widget on a config change. MyApp pushes an
 * update from `didChangePlatformBrightness` to cover that.
 *
 * ON_ACCENT resolves to the same dark value in both themes: it sits on the
 * pastel fills, which don't change between themes.
 */
private val TEXT_PRIMARY = ColorProvider(R.color.widget_text_primary)
private val TEXT_SECONDARY = ColorProvider(R.color.widget_text_secondary)
private val TEXT_TERTIARY = ColorProvider(R.color.widget_text_tertiary)
private val HOST = ColorProvider(R.color.widget_host)
private val ON_ACCENT = ColorProvider(R.color.widget_on_accent)

/**
 * Today's resurface pick + Inbox/unread counts on the home screen.
 *
 * ## Fixed size, single layout
 * [SizeMode.Single] with `resizeMode="none"` in today_widget_info.xml: one
 * layout designed for one size (4x2, 250x110dp). Earlier versions used
 * [SizeMode.Responsive] with four declared tiers, and every bug in this
 * widget's history was a sizing bug — a tier declared wider than the space
 * it was meant for became unreachable, so a 2x2 widget silently fell back
 * to showing nothing but a count. A fixed size removes that whole category.
 *
 * ## Layout rules
 * - **No nested bordered card.** A widget is already a container; a heavy
 *   frame just inside the launcher's own frame reads as clutter. The widget
 *   does supply its own *surface* though — without one the content lands on
 *   the user's wallpaper and light-mode text vanishes against a dark one.
 * - **Neo-Brutalist accents only where they earn it** — the stat pills, not
 *   every element.
 * - **A weighted Spacer absorbs slack**, so text sits at the top and stats
 *   at the bottom rather than leaving a void in the middle.
 * - **The widget identifies itself.** An unbranded box on the home screen
 *   gives the user no idea which app it belongs to.
 */
class TodayGlanceWidget : GlanceAppWidget() {

  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode = SizeMode.Single

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      val data = currentState<HomeWidgetGlanceState>().preferences

      TodayWidgetContent(
          context = context,
          hasPick = data.getBoolean("has_pick", false),
          pickTitle = data.getString("pick_title", null) ?: "",
          pickHost = data.getString("pick_host", null) ?: "",
          inboxCount = data.getInt("inbox_count", 0),
          unreadCount = data.getInt("unread_count", 0),
      )
    }
  }
}

@Composable
private fun TodayWidgetContent(
    context: Context,
    hasPick: Boolean,
    pickTitle: String,
    pickHost: String,
    inboxCount: Int,
    unreadCount: Int,
) {
  val homeIntent = actionStartActivity<MainActivity>(context, Uri.parse("$SCHEME://home"))

  // The whole widget is the tap target, not just the text block.
  //
  // Android's convention is that a widget is tappable everywhere, and the
  // alternative here was actively bad: with the click only on PickBlock, the
  // dead area was the brand row, the padding ring and the weighted Spacer —
  // and the Spacer's size depends on how many lines the title wraps to. A
  // one-line title left a wide dead band, a three-line title almost none, so
  // whether a tap in the middle did anything changed from link to link.
  //
  // With a pick, Dart resolves the candidate itself and opens it in an in-app
  // browser, marking it read + resurfaced. The app has to run for those
  // writes, which is why this isn't a direct ACTION_VIEW at the browser.
  //
  // Deliberately carries no link id. An earlier version passed one, which
  // broke on the very first install: the id was a new key, the widget's
  // stored prefs were written by the previous build and didn't have it, so
  // the tap silently fell back to opening the app. The widget is a *view* —
  // making it also carry an identity Dart has to trust adds a whole class of
  // cross-process staleness for nothing. "Today's pick" is a question Dart
  // can answer at tap time, and if the pick moved between draw and tap, the
  // current one is the right answer anyway.
  val primaryIntent =
      if (hasPick) {
        actionStartActivity<MainActivity>(context, Uri.parse("$SCHEME://open"))
      } else {
        homeIntent
      }

  Box(
      modifier = GlanceModifier
          .fillMaxSize()
          .appWidgetBackground()
          .background(ImageProvider(R.drawable.widget_background))
          .clickable(primaryIntent)
          .padding(16.dp)
  ) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
      BrandRow()
      Spacer(modifier = GlanceModifier.height(12.dp))
      PickBlock(hasPick, pickTitle, pickHost)
      Spacer(modifier = GlanceModifier.defaultWeight())
      // Keeps its own click: a child view consumes the touch before the root,
      // so the pills still go to the app rather than opening the link.
      StatsRow(inboxCount, unreadCount, homeIntent)
    }
  }
}

// ─── Pieces ─────────────────────────────────────────────────────────────────

/** Icon + wordmark, so the widget is identifiable as LinkHive at a glance. */
@Composable
private fun BrandRow() {
  Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
    Image(
        provider = ImageProvider(R.mipmap.ic_launcher),
        contentDescription = null,
        modifier = GlanceModifier.size(22.dp),
    )
    Spacer(modifier = GlanceModifier.width(8.dp))
    Text(
        "LinkHive",
        style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = TEXT_SECONDARY),
    )
  }
}

@Composable
private fun PickBlock(hasPick: Boolean, pickTitle: String, pickHost: String) {
  Column(modifier = GlanceModifier.fillMaxWidth()) {
    Text(
        if (hasPick) "TODAY'S PICK" else "NOTHING WAITING",
        style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Bold, color = TEXT_TERTIARY),
    )
    Spacer(modifier = GlanceModifier.height(7.dp))
    Text(
        if (hasPick) pickTitle else "All caught up",
        // 3 lines rather than 2: a long title filling more of the widget is
        // better than truncating it and leaving the space empty instead.
        maxLines = 3,
        style = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, color = TEXT_PRIMARY),
    )
    if (hasPick && pickHost.isNotEmpty()) {
      Spacer(modifier = GlanceModifier.height(6.dp))
      Text(
          pickHost,
          maxLines = 1,
          style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, color = HOST),
      )
    }
  }
}

@Composable
private fun StatsRow(inboxCount: Int, unreadCount: Int, onClick: Action) {
  Row(modifier = GlanceModifier.fillMaxWidth().clickable(onClick)) {
    Pill("Inbox $inboxCount", R.drawable.widget_pill_orange)
    Spacer(modifier = GlanceModifier.width(8.dp))
    Pill("Unread $unreadCount", R.drawable.widget_pill_blue)
  }
}

@Composable
private fun Pill(label: String, bgDrawable: Int) {
  Box(
      modifier = GlanceModifier
          .background(ImageProvider(bgDrawable))
          .padding(horizontal = 13.dp, vertical = 7.dp)
  ) {
    Text(
        label,
        maxLines = 1,
        style = TextStyle(
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            // Constant dark — the pastel fill behind it doesn't change
            // between themes, so this must not either.
            color = ON_ACCENT,
        ),
    )
  }
}
