package fr.lahocy.topolink

import android.content.Context

object Prefs {
    private const val NAME = "topolink"

    fun stationAddress(ctx: Context): String = ctx.getSharedPreferences(NAME, 0).getString("station_address", "") ?: ""
    fun stationName(ctx: Context): String = ctx.getSharedPreferences(NAME, 0).getString("station_name", "") ?: ""
    fun setStation(ctx: Context, address: String, name: String) {
        ctx.getSharedPreferences(NAME, 0).edit().putString("station_address", address).putString("station_name", name).apply()
    }
    fun port(ctx: Context): Int = ctx.getSharedPreferences(NAME, 0).getInt("port", 8765)
}
