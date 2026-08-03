pragma Singleton
import QtQuick 2.15
import LiquidacionSueldos 1.0

QtObject {
    // ── Current mode bound dynamically to AppController ─────────
    property bool isDark: AppController.darkMode

    // ── Background & Surface colors ─────────────────────────────
    readonly property color bgColor:      isDark ? "#1e1e2e" : "#f4f5f8"
    readonly property color panelBg:      isDark ? "#252538" : "#ffffff"
    readonly property color cardBg:       isDark ? "#2b2b40" : "#ffffff"
    readonly property color inputBg:      isDark ? "#1e1e2e" : "#f8f9fa"
    readonly property color headerBg:     isDark ? "#181825" : "#eef0f4"

    // ── Accent & Brand ──────────────────────────────────────────
    readonly property color accentColor:  isDark ? "#74c7ec" : "#007acc"

    // ── Text ────────────────────────────────────────────────────
    readonly property color textColor:    isDark ? "#cdd6f4" : "#1e1e2e"
    readonly property color subtextColor: isDark ? "#a6adc8" : "#5c6070"

    // ── Semantic status colors ──────────────────────────────────
    readonly property color successColor: isDark ? "#a6e3a1" : "#2e7d32"
    readonly property color dangerColor:  isDark ? "#f38ba8" : "#c62828"
    readonly property color warningColor: isDark ? "#fab387" : "#e65100"
    readonly property color infoColor:    isDark ? "#89b4fa" : "#1565c0"

    // ── Borders ─────────────────────────────────────────────────
    readonly property color borderColor:  isDark ? "#383852" : "#d0d4dc"

    // ── Hover/Selection states ──────────────────────────────────
    readonly property color hoverBg:      isDark ? "#303045" : "#ebedf2"
    readonly property color selectedBg:   isDark ? "#3b3b58" : "#e0e3ed"

    // ── Receipt section semantic colors ──────────────────────────
    readonly property color remunerativoColor:   isDark ? "#a6e3a1" : "#2e7d32"
    readonly property color noRemunerativoColor: isDark ? "#89b4fa" : "#1565c0"
    readonly property color descuentoColor:      isDark ? "#f38ba8" : "#c62828"
    readonly property color aportePatronalColor: isDark ? "#fab387" : "#e65100"

    // ── Helper functions ────────────────────────────────────────
    function sectionColor(code) {
        if (code === "REMUNERATIVO")     return remunerativoColor
        if (code === "NO_REMUNERATIVO")  return noRemunerativoColor
        if (code === "DESCUENTO")        return descuentoColor
        if (code === "APORTE_PATRONAL")  return aportePatronalColor
        return accentColor
    }
}
