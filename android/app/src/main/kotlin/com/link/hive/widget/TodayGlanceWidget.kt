package com.link.hive.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
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
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.link.hive.MainActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity

/// Deep-link scheme the Dart side (HomeWidgetService) reads back via
/// HomeWidget.widgetClicked / initiallyLaunchedFromHomeWidget.
private const val SCHEME = "linkhive"

private val SIZE_SMALL = DpSize(110.dp, 40.dp)
private val SIZE_MEDIUM = DpSize(250.dp, 110.dp)
private val SIZE_LARGE = DpSize(250.dp, 250.dp)

class TodayGlanceWidget : GlanceAppWidget() {

  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode = SizeMode.Responsive(setOf(SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE))

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      val state = currentState<HomeWidgetGlanceState>()
      val data = state.preferences

      val hasPick = data.getBoolean("has_pick", false)
      val pickTitle = data.getString("pick_title", null) ?: ""
      val pickHost = data.getString("pick_host", null) ?: ""
      val inboxCount = data.getInt("inbox_count", 0)
      val unreadCount = data.getInt("unread_count", 0)

      TodayWidgetContent(
          context = context,
          hasPick = hasPick,
          pickTitle = pickTitle,
          pickHost = pickHost,
          inboxCount = inboxCount,
          unreadCount = unreadCount,
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
  val size = androidx.glance.LocalSize.current
  val todayIntent = actionStartActivity<MainActivity>(context, Uri.parse("$SCHEME://today"))
  val homeIntent = actionStartActivity<MainActivity>(context, Uri.parse("$SCHEME://home"))

  when {
    size.height <= SIZE_SMALL.height -> SmallContent(inboxCount + unreadCount, homeIntent)
    size.height <= SIZE_MEDIUM.height ->
        MediumContent(hasPick, pickTitle, pickHost, inboxCount, unreadCount, todayIntent, homeIntent)
    else ->
        LargeContent(hasPick, pickTitle, pickHost, inboxCount, unreadCount, todayIntent, homeIntent)
  }
}

// ─── Small: one glanceable number ──────────────────────────────────────────
@Composable
private fun SmallContent(waitingCount: Int, homeIntent: androidx.glance.action.Action) {
  ShadowCard(modifier = GlanceModifier.fillMaxSize().clickable(homeIntent)) {
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(8.dp),
        horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
        verticalAlignment = Alignment.Vertical.CenterVertically,
    ) {
      Text(
          "$waitingCount",
          style = TextStyle(
              fontSize = 24.sp,
              fontWeight = FontWeight.Bold,
              color = ColorProvider(com.link.hive.R.color.widget_text_primary),
          ),
      )
      Text(
          "waiting",
          style = TextStyle(fontSize = 10.sp, color = ColorProvider(com.link.hive.R.color.widget_text_tertiary)),
      )
    }
  }
}

// ─── Medium: pick + stats row ───────────────────────────────────────────────
@Composable
private fun MediumContent(
    hasPick: Boolean,
    pickTitle: String,
    pickHost: String,
    inboxCount: Int,
    unreadCount: Int,
    todayIntent: androidx.glance.action.Action,
    homeIntent: androidx.glance.action.Action,
) {
  Column(modifier = GlanceModifier.fillMaxSize().padding(4.dp)) {
    PickBlock(hasPick, pickTitle, pickHost, todayIntent, modifier = GlanceModifier.fillMaxWidth())
    Spacer(modifier = GlanceModifier.height(6.dp))
    StatsRow(inboxCount, unreadCount, homeIntent)
  }
}

// ─── Large: pick + stats + mini action row ─────────────────────────────────
@Composable
private fun LargeContent(
    hasPick: Boolean,
    pickTitle: String,
    pickHost: String,
    inboxCount: Int,
    unreadCount: Int,
    todayIntent: androidx.glance.action.Action,
    homeIntent: androidx.glance.action.Action,
) {
  Column(modifier = GlanceModifier.fillMaxSize().padding(4.dp)) {
    PickBlock(
        hasPick,
        pickTitle,
        pickHost,
        todayIntent,
        modifier = GlanceModifier.fillMaxWidth().defaultWeight(),
    )
    Spacer(modifier = GlanceModifier.height(6.dp))
    StatsRow(inboxCount, unreadCount, homeIntent)
    Spacer(modifier = GlanceModifier.height(6.dp))
    // v1: all three just deep-link into Today, pre-loaded with the same pick
    // — no instant in-widget actions yet (see HomeWidgetService doc comment).
    Row(modifier = GlanceModifier.fillMaxWidth()) {
      MiniButton("Snooze", todayIntent, modifier = GlanceModifier.defaultWeight())
      Spacer(modifier = GlanceModifier.width(6.dp))
      MiniButton("Archive", todayIntent, modifier = GlanceModifier.defaultWeight())
      Spacer(modifier = GlanceModifier.width(6.dp))
      MiniButton("Open", todayIntent, modifier = GlanceModifier.defaultWeight(), filled = true)
    }
  }
}

// ─── Shared pieces ──────────────────────────────────────────────────────────

@Composable
private fun PickBlock(
    hasPick: Boolean,
    pickTitle: String,
    pickHost: String,
    onClick: androidx.glance.action.Action,
    modifier: GlanceModifier,
) {
  ShadowCard(modifier = modifier.clickable(onClick)) {
    Column(modifier = GlanceModifier.fillMaxSize().padding(10.dp)) {
      Text(
          "TODAY'S PICK",
          style = TextStyle(
              fontSize = 10.sp,
              fontWeight = FontWeight.Bold,
              color = ColorProvider(com.link.hive.R.color.widget_text_tertiary),
          ),
      )
      Spacer(modifier = GlanceModifier.height(4.dp))
      Text(
          if (hasPick) pickTitle else "All caught up",
          maxLines = 2,
          style = TextStyle(
              fontSize = 14.sp,
              fontWeight = FontWeight.Bold,
              color = ColorProvider(com.link.hive.R.color.widget_text_primary),
          ),
      )
      if (hasPick) {
        Text(
            pickHost,
            maxLines = 1,
            style = TextStyle(fontSize = 11.sp, color = ColorProvider(com.link.hive.R.color.widget_accent_blue)),
        )
      }
    }
  }
}

@Composable
private fun StatsRow(inboxCount: Int, unreadCount: Int, onClick: androidx.glance.action.Action) {
  Row(modifier = GlanceModifier.fillMaxWidth().clickable(onClick)) {
    Pill("Inbox $inboxCount", com.link.hive.R.color.widget_accent_orange)
    Spacer(modifier = GlanceModifier.width(6.dp))
    Pill("Unread $unreadCount", com.link.hive.R.color.widget_accent_blue)
  }
}

@Composable
private fun Pill(label: String, bgColorRes: Int) {
  Box(
      modifier = GlanceModifier.background(ColorProvider(bgColorRes)).padding(horizontal = 8.dp, vertical = 4.dp)
  ) {
    Text(
        label,
        style = TextStyle(
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = ColorProvider(com.link.hive.R.color.widget_text_primary),
        ),
    )
  }
}

@Composable
private fun MiniButton(
    label: String,
    onClick: androidx.glance.action.Action,
    modifier: GlanceModifier,
    filled: Boolean = false,
) {
  Box(
      modifier = modifier
          .background(
              ColorProvider(
                  if (filled) com.link.hive.R.color.widget_success else com.link.hive.R.color.widget_surface
              )
          )
          .padding(horizontal = 6.dp, vertical = 6.dp)
          .clickable(onClick),
  ) {
    Text(
        label,
        style = TextStyle(
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = ColorProvider(com.link.hive.R.color.widget_text_primary),
        ),
    )
  }
}

/**
 * The two-box Neo-Brutalist card: a solid shadow layer behind, a bordered
 * surface on top inset by 4dp from the bottom/end edge via padding — Glance
 * has no true `.offset()` modifier, so the same visual is achieved by
 * shrinking the foreground layer's own paint bounds instead of translating
 * it, revealing the shadow layer underneath along those two edges.
 */
@Composable
private fun ShadowCard(modifier: GlanceModifier, content: @Composable () -> Unit) {
  Box(modifier = modifier.background(ImageProvider(com.link.hive.R.drawable.widget_card_shadow))) {
    Box(
        modifier = GlanceModifier.fillMaxSize()
            .padding(end = 4.dp, bottom = 4.dp)
            .background(ImageProvider(com.link.hive.R.drawable.widget_card_bg)),
    ) {
      content()
    }
  }
}
