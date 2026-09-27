package com.link.hive.widget

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/** Registered in AndroidManifest.xml, pointed at res/xml/today_widget_info.xml. */
class TodayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayGlanceWidget>() {
  override val glanceAppWidget = TodayGlanceWidget()
}
