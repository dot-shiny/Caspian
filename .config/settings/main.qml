import QtQuick 6.0
import QtQuick.Layouts 6.0
import QtQuick.Controls 6.0

ApplicationWindow {
    id: window
    title: "Настройки ноутбука"
    width: 850
    height: 550
    visible: true

    readonly property color bgMain: "#1e1e2e"
    readonly property color bgSidebar: "#181825"
    readonly property color bgCard: "#252538"
    readonly property color textMain: "#cdd6f4"
    readonly property color accent: "#f5c2e7"

    background: Rectangle { color: window.bgMain }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. БОКОВОЕ МЕНЮ
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            color: window.bgSidebar

            Rectangle { 
                anchors.right: parent.right
                width: 1; height: parent.height
                color: "#313244"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8

                Text {
                    text: "Settings"
                    color: window.textMain
                    font.pointSize: 16
                    font.bold: true
                    Layout.bottomMargin: 15
                }

                Button {
                    id: btnSys
                    Layout.fillWidth: true
                    height: 40
                    background: Rectangle { color: stack.currentIndex === 0 ? "#313244" : "transparent"; radius: 6 }
                    contentItem: Text { text: "💻  Система и Батарея"; color: stack.currentIndex === 0 ? window.accent : "#a6adc8"; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
                    onClicked: stack.currentIndex = 0
                }

                Button {
                    id: btnDev
                    Layout.fillWidth: true
                    height: 40
                    background: Rectangle { color: stack.currentIndex === 1 ? "#313244" : "transparent"; radius: 6 }
                    contentItem: Text { text: "🎧  Подключенные устройства"; color: stack.currentIndex === 1 ? window.accent : "#a6adc8"; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
                    onClicked: stack.currentIndex = 1
                }

                Item { Layout.fillHeight: true } 
            }
        }

        // 2. ОСНОВНОЙ КОНТЕНТ
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // ВКЛАДКА 0: СИСТЕМА
            ScrollView {
                clip: true
                ColumnLayout {
                    width: parent.width - 40
                    Layout.margins: 25
                    spacing: 15

                    Text { text: "Система и параметры"; color: "#ffffff"; font.pointSize: 18; font.bold: true }
                    Text { text: "Здесь будут настройки питания, экрана и тачпада."; color: "#a6adc8" }
                    
                    Rectangle {
                        Layout.fillWidth: true; height: 70; color: window.bgCard; radius: 8
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 15
                            Text { text: "🔋 Режим энергопотребления"; color: window.textMain; font.bold: true }
                            Item { Layout.fillWidth: true }
                            ComboBox { model: ["Энергосбережение", "Сбалансированный", "Производительность"] }
                        }
                    }
                }
            }

            // ВКЛАДКА 1: ВСЕ ПОДКЛЮЧЕННЫЕ УСТРОЙСТВА
            ScrollView {
                clip: true
                ColumnLayout {
                    width: parent.width - 40
                    Layout.margins: 25
                    spacing: 15

                    Text { text: "Подключенные устройства"; color: "#ffffff"; font.pointSize: 18; font.bold: true }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: btModel 
                            
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 55
                                color: model.connected ? "#2d2438" : window.bgCard
                                radius: 8
                                border.color: model.connected ? window.accent : "#313244"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 12
                                    
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: model.name; color: "#ffffff"; font.bold: true }
                                        Text { 
                                            text: model.mac === "USB" ? "Проводное / Радио-интерфейс" : (model.mac + (model.connected ? " (Подключено)" : " (Сохранено)"))
                                            color: model.connected ? window.accent : "#89b4fa"
                                            font.pointSize: 9 
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Кнопки управления скрываются, если это USB устройство
                                    Button {
                                        text: model.connected ? "Отключить" : "Подключить"
                                        visible: model.mac !== "USB"
                                        onClicked: backend.toggle_connect(model.mac, model.connected)
                                    }

                                    Button {
                                        text: "🗑️"
                                        visible: model.mac !== "USB"
                                        onClicked: backend.remove_device(model.mac)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
