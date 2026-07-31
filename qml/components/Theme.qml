pragma Singleton
import QtQuick 2.15

QtObject {
    // ── Current mode ─────────────────────────────────────────────
    property bool isDark: true

    // ── Background & Surface colors ─────────────────────────────
    readonly property color bgColor:      isDark ? "#1e1e2e" : "#f5f5f8"
    readonly property color panelBg:      isDark ? "#252538" : "#ffffff"
    readonly property color cardBg:       isDark ? "#2b2b40" : "#f8f8fc"
    readonly property color inputBg:      isDark ? "#1e1e2e" : "#ffffff"
    readonly property color headerBg:     isDark ? "#181825" : "#eaeaf0"

    // ── Accent & Brand ──────────────────────────────────────────
    readonly property color accentColor:  "#74c7ec"

    // ── Text ────────────────────────────────────────────────────
    readonly property color textColor:    isDark ? "#cdd6f4" : "#1e1e2e"
    readonly property color subtextColor: isDark ? "#a6adc8" : "#6c6c80"

    // ── Semantic status colors ──────────────────────────────────
    readonly property color successColor: "#a6e3a1"
    readonly property color dangerColor:  "#f38ba8"
    readonly property color warningColor: "#fab387"
    readonly property color infoColor:    "#89b4fa"

    // ── Borders ─────────────────────────────────────────────────
    readonly property color borderColor:  isDark ? "#383852" : "#e0e0e8"

    // ── Hover/Selection states ──────────────────────────────────
    readonly property color hoverBg:      isDark ? "#303045" : "#f0f0f5"
    readonly property color selectedBg:   isDark ? "#3b3b58" : "#e4e4e9"

    // ── Receipt section semantic colors ──────────────────────────
    readonly property color remunerativoColor:   "#a6e3a1"
    readonly property color noRemunerativoColor: "#89b4fa"
    readonly property color descuentoColor:      "#f38ba8"
    readonly property color aportePatronalColor: "#fab387"

    // ── Helper functions ────────────────────────────────────────
    function sectionColor(code) {
        if (code === "REMUNERATIVO")     return remunerativoColor
        if (code === "NO_REMUNERATIVO")  return noRemunerativoColor
        if (code === "DESCUENTO")        return descuentoColor
        if (code === "APORTE_PATRONAL")  return aportePatronalColor
        return accentColor
    }
}
