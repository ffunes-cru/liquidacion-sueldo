import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    // ── Master panel (left) ─────────────────────────────────────
    property int masterWidth: 380
    property string masterTitle: ""
    property string masterCountSuffix: ""
    property var masterModel: null
    property Component masterDelegate: null
    property int selectedIndex: -1

    // ── Master footer slot ──────────────────────────────────────
    property alias masterFooter: masterFooterContainer.data

    // ── Detail panel (right) ────────────────────────────────────
    default property alias detailContent: detailContentContainer.data

    // ── Signals ─────────────────────────────────────────────────
    signal masterItemSelected(var itemData, int index)

    SplitView {
        anchors.fill: parent
        anchors.margins: 12
        orientation: Qt.Horizontal

        handle: Rectangle {
            implicitWidth: 8
            color: "transparent"
            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 36
                radius: 2
                color: SplitHandle.hovered || SplitHandle.pressed ? Theme.accentColor : Qt.rgba(255, 255, 255, 0.15)
            }
        }

        // ═══════════════════════════════════════════════════════
        // MASTER PANEL (Left)
        // ═══════════════════════════════════════════════════════
        Rectangle {
            SplitView.preferredWidth: root.masterWidth
            SplitView.minimumWidth: 260
            SplitView.maximumWidth: 600
            SplitView.fillHeight: true
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: root.masterTitle
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.textColor
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        visible: root.masterCountSuffix !== ""
                        text: (root.masterModel && root.masterModel.count !== undefined ? root.masterModel.count : 0) + " " + root.masterCountSuffix
                        font.pixelSize: 12
                        color: Theme.subtextColor
                    }
                }

                // List
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: masterListView
                        model: root.masterModel
                        spacing: 6
                        delegate: root.masterDelegate
                        currentIndex: root.selectedIndex
                        highlightFollowsCurrentItem: false
                    }
                }

                // Footer slot (buttons, etc.)
                ColumnLayout {
                    id: masterFooterContainer
                    Layout.fillWidth: true
                    spacing: 8
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // DETAIL PANEL (Right)
        // ═══════════════════════════════════════════════════════
        Rectangle {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 300
            SplitView.fillHeight: true
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            ColumnLayout {
                id: detailContentContainer
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
            }
        }
    }
}
