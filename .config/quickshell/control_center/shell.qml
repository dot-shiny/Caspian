pragma ComponentBehavior: Bound

import QtQuick.Layouts
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: rootShell

    objectName: "controlCenter"
    property bool visibleState: false

    // Системные свойства для хранения данных
    property string currentWifi: "Disconnected"
    property string currentBluetooth: "Disconnected"
    property int volumeValue: 50
    property int brightnessValue: 50

    // Модели данных объявлены в самом верху ShellRoot
    ListModel {
        id: wifiNetworksModel
    }

    ListModel {
        id: bluetoothDevicesModel
    }

    // 1. Процесс получения имени текущей Wi-Fi сети
    Process {
        id: getWifiProc
        command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2"]
        running: false
        stdout: StdioCollector {
            id: wifiCollector
            onStreamFinished: {
                let res = wifiCollector.text.trim();
                rootShell.currentWifi = res.length > 0 ? res : "Disconnected";
            }
        }
    }

    // 2. Умное сканирование Wi-Fi сетей (сортировка сохраненных + флаг подсветки)
    Process {
        id: scanWifiProc
        command: ["bash", "-c", "
            saved_ssids=$(nmcli -g NAME connection show | grep -v -E '^(lo|Wired|bridge)');
            echo -n '[';
            nmcli -t -f ssid dev wifi | grep -v '^$' | sort -u | while read -r ssid; do
                if echo \"$saved_ssids\" | grep -Fxq \"$ssid\"; then
                    echo \"{\\\"ssidName\\\":\\\"$ssid\\\",\\\"isSaved\\\":true},\";
                else
                    echo \"{\\\"ssidName\\\":\\\"$ssid\\\",\\\"isSaved\\\":false},\";
                fi
            done | sed '$ s/,$//';
            echo ']';
        "]
        running: false
        stdout: StdioCollector {
            id: scanWifiCollector
            onStreamFinished: {
                let rawText = scanWifiCollector.text.trim();
                wifiNetworksModel.clear();
                if (rawText.length > 2) {
                    try {
                        let networksArray = JSON.parse(rawText);
                        
                        // Сортируем: сначала те, у которых isSaved === true
                        networksArray.sort(function(a, b) { 
                            return (b.isSaved ? 1 : 0) - (a.isSaved ? 1 : 0); 
                        });

                        for (let i = 0; i < networksArray.length; i++) {
                            let item = networksArray[i];
                            if (item.ssidName !== rootShell.currentWifi) {
                                wifiNetworksModel.append({
                                    "ssidName": item.ssidName,
                                    "isSaved": item.isSaved
                                });
                            }
                        }
                    } catch(e) {
                        console.log("Ошибка парсинга Wi-Fi JSON: " + e);
                    }
                }
            }
        }
    }


    // 1. Постоянный фоновый сканер (запускается один раз и работает всегда)
    Process {
        id: permanentBluetoothScanner
        command: ["bluetoothctl", "scan", "on"]
        running: true // Запускается автоматически при старте виджета
    }

    // 2. Сбор Bluetooth устройств: жесткое приведение типов данных + исправление isActive
    Process {
        id: scanBluetoothProc
        command: ["bash", "-c", "
            macs=$( (bluetoothctl paired-devices | awk '{print $2}'; bluetoothctl devices | head -n 6 | awk '{print $2}') | sort -u );
            
            for mac in $macs; do
                if [ -n \"$mac\" ]; then
                    info_text=$(bluetoothctl info \"$mac\");
                    name=$(echo \"$info_text\" | grep 'Name:' | cut -d' ' -f2-);
                    is_paired=\"false\";
                    is_active=\"false\";
                    if echo \"$info_text\" | grep -q 'Paired: yes'; then is_paired=\"true\"; fi;
                    if echo \"$info_text\" | grep -q 'Connected: yes'; then is_active=\"true\"; fi;
                    
                    echo \"$mac|$name|$is_paired|$is_active\";
                fi;
            done
        "]
        running: false
        stdout: StdioCollector {
            id: btCollector
            onStreamFinished: {
                let txt = btCollector.text.toString().trim(); // Принудительно в строку
                bluetoothDevicesModel.clear();
                
                // Сбрасываем глобальный статус перед проверкой
                rootShell.currentBluetooth = "Disconnected";

                if (txt.length > 0) {
                    try {
                        let lines = txt.split('\n');
                        let tempArray = [];
                        let seenNames = {};

                        for (let i = 0; i < lines.length; i++) {
                            let line = lines[i].trim();
                            if (line.length === 0) continue;

                            let parts = line.split('|');
                            if (parts.length >= 4) {
                                // ПРАВИЛЬНОЕ ИЗВЛЕЧЕНИЕ ИЗ МАССИВА ПО ИНДЕКСАМ:
                                let devMac = parts[0].trim();
                                let devName = parts[1].trim();
                                
                                // Честно переводим текстовые флаги bash в булевы значения JS
                                let isPaired = parts[2].trim() === "true";
                                let isActive = parts[3].trim() === "true";

                                let cleanMac = devMac.toLowerCase().replace(/[^a-f0-9]/g, '');
                                let cleanName = devName.toLowerCase().replace(/[^a-f0-9]/g, '');
                                if (devName.length === 0 || cleanMac === cleanName) {
                                    devName = "fifine x3";
                                }

                                // Если нашли хоть одно устройство со статусом Connected, выводим его в глобальный статус
                                if (isActive) {
                                    rootShell.currentBluetooth = devName;
                                }

                                if (seenNames[devName]) {
                                    if (isActive) {
                                        for (let j = 0; j < tempArray.length; j++) {
                                            if (tempArray[j].devName === devName) {
                                                tempArray[j].isActive = true;
                                                tempArray[j].isPaired = true;
                                            }
                                        }
                                    }
                                    continue;
                                }
                                seenNames[devName] = true;

                                tempArray.push({
                                    "devName": devName,
                                    "devMac": devMac,
                                    "isPaired": isPaired,
                                    "isActive": isActive
                                });
                            }
                        }

                        // Сортируем: Активные -> Сопряженные -> Свободный эфир
                        tempArray.sort(function(a, b) {
                            if (a.isActive !== b.isActive) return b.isActive - a.isActive;
                            return b.isPaired - a.isPaired;
                        });

                        for (let i = 0; i < Math.min(tempArray.length, 4); i++) {
                            bluetoothDevicesModel.append({
                                "deviceName": tempArray[i].devName,
                                "deviceMac": tempArray[i].devMac,
                                "isPaired": tempArray[i].isPaired,
                                "isActive": tempArray[i].isActive
                            });
                        }

                    } catch(e) {
                        console.log("Ошибка обработки Bluetooth: " + e);
                    }
                }

                if (bluetoothDevicesModel.count === 0) {
                    bluetoothDevicesModel.append({ "deviceName": "Searching for devices...", "deviceMac": "", "isPaired": false, "isActive": false });
                }
            }
        }
    }


    // 3. Таймер для обновления списка Bluetooth каждую секунду
    Timer {
        id: bluetoothUpdateTimer
        interval: 1000 // 1 секунда
        repeat: true
        running: rootShell.visibleState && btBtn.expanded // Работает только когда открыта вкладка Bluetooth
        onTriggered: {
            scanBluetoothProc.running = false;
            scanBluetoothProc.running = true;
        }
    }

    // Новый процесс для фонового сканирования эфира
    Process {
        id: startBluetoothScanProc
        command: ["bash", "-c", "bluetoothctl --timeout 4 scan on"]
        running: false
        
        // Как только фоновый поиск (4 секунды) завершился — обновляем список устройств
        onExited: function(exitCode, exitStatus) {
            scanBluetoothProc.running = false;
            scanBluetoothProc.running = true;
        }
    }

    // 4. Процесс чтения звука
    Process {
        id: getVolumeProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}'"]
        running: false
        stdout: StdioCollector {
            id: volCollector
            onStreamFinished: {
                let txt = volCollector.text.trim();
                if (txt.length > 0) {
                    let val = parseInt(txt);
                    if (!isNaN(val)) rootShell.volumeValue = val;
                }
            }
        }
    }

    // 5. Процесс чтения яркости
    Process {
        id: getBrightnessProc
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        running: false
        stdout: StdioCollector {
            id: briCollector
            onStreamFinished: {
                let txt = briCollector.text.trim();
                if (txt.length > 0) {
                    let val = parseInt(txt);
                    if (!isNaN(val)) rootShell.brightnessValue = val;
                }
            }
        }
    }

    // Вспомогательные процессы для отправки изменений в систему
    Process { id: setVolumeProc }
    Process { id: setBrightnessProc }
    Process { id: disconnectWifiProc; command: ["bash", "-c", "nmcli dev disconnect $(nmcli dev | grep wifi | awk '{print $1}' | head -n 1)"] }
    Process { id: connectWifiProc }
    Process { id: connectBtProc }

    // ЕДИНЫЙ ОБЪЕДИНЕННЫЙ МЕТОД ОБНОВЛЕНИЯ СИСТЕМЫ
    function updateSystemStatus() {
        getVolumeProc.running = false; getVolumeProc.running = true;
        getBrightnessProc.running = false; getBrightnessProc.running = true;
        getWifiProc.running = false; getWifiProc.running = true;
        if (wifiBtn.expanded) {
            scanWifiProc.running = false; scanWifiProc.running = true;
        }
        
        // ИСПРАВЛЕННЫЙ ТРИГГЕР:
        if (btBtn.expanded) {
            // Запускаем фоновый поиск новых устройств поблизости
            startBluetoothScanProc.running = false;
            startBluetoothScanProc.running = true;
        }
    }

    function toggle() {
        visibleState = !visibleState;
        if (visibleState) {
            updateSystemStatus();
        }
    }

    IpcHandler {
        target: "controlCenter"
        function toggle() {
            rootShell.toggle();
        }
    }
    PanelWindow {
        id: rootWindow

        aboveWindows: true
        exclusionMode: PanelWindow.NoExclusion

        WlrLayershell.keyboardFocus: rootShell.visibleState ? WlrLayershell.OnDemand : WlrLayershell.None

        implicitWidth: 360
        implicitHeight: rootShell.visibleState ? (contentColumn.implicitHeight + 30) : 0

        anchors.top: true
        anchors.bottom: false
        anchors.left: false
        anchors.right: true

        margins.top: 10
        margins.right: 5

        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#1a1a1a"
            border.color: "#fa0567"
            border.width: 2
            radius: 12
            clip: true
            visible: rootShell.visibleState

            Column {
                id: contentColumn
                width: parent.width - 30
                anchors.centerIn: parent
                spacing: 15

                // --- КНОПКИ СЕТИ И БЛЮТУЗ ---
                Row {
                    width: parent.width
                    spacing: 15

                    Button {
                        id: wifiBtn
                        width: (parent.width - 15) / 2
                        height: 45
                        property bool expanded: false

                        background: Rectangle {
                            color: wifiBtn.expanded ? "#73022f" : "#222222"
                            border.color: "#fa0567"
                            radius: 8
                        }
                        contentItem: Text {
                            text: "    Network"
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            wifiBtn.expanded = !wifiBtn.expanded
                            btBtn.expanded = false
                            if (wifiBtn.expanded) {
                                scanWifiProc.running = false; scanWifiProc.running = true;
                            }
                        }
                    }

                    Button {
                        id: btBtn
                        width: (parent.width - 15) / 2
                        height: 45
                        property bool expanded: false

                        background: Rectangle {
                            color: btBtn.expanded ? "#73022f" : "#222222"
                            border.color: "#fa0567"
                            radius: 8
                        }
                        contentItem: Text {
                            text: "    Bluetooth"
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            btBtn.expanded = !btBtn.expanded
                            wifiBtn.expanded = false
                            if (btBtn.expanded) {
                                scanBluetoothProc.running = false; scanBluetoothProc.running = true;
                            }
                        }
                    }
                }

                // --- ПОДМЕНЮ WI-FI ---
                Column {
                    width: parent.width
                    spacing: 8
                    visible: wifiBtn.expanded

                    Text { 
                        text: "Connected: " + rootShell.currentWifi
                        color: "#fa0567"
                        font.bold: true 
                    }

                    Button {
                        text: "Disconnect"
                        visible: rootShell.currentWifi !== "Disconnected"
                        onClicked: {
                            disconnectWifiProc.running = false;
                            disconnectWifiProc.running = true;
                            rootShell.updateSystemStatus();
                        }
                    }

                    Text { text: "Available Networks:"; color: "#ffffff" }

                    ScrollView {
                        width: parent.width
                        height: wifiNetworksModel.count > 0 ? Math.min(wifiNetworksModel.count * 40, 120) : 0
                        clip: true

                        Column {
                            width: parent.width
                            spacing: 5

                            Repeater {
                                model: wifiNetworksModel
                                delegate: Rectangle {
                                    required property int index
                                    required property string ssidName
                                    required property bool isSaved // Принудительно связываем новое свойство

                                    width: contentColumn.width; height: 35; radius: 4
                                    
                                    // ЭФФЕКТ СВЕЧЕНИЯ: Сохраненные сети красятся в темно-розовый, обычные - в серый
                                    color: isSaved ? "#4d0220" : "#222222"
                                    border.color: isSaved ? "#fa0567" : "transparent"
                                    border.width: isSaved ? 1 : 0

                                    Text { 
                                        text: "     " + ssidName
                                        // Текст сохраненной сети делаем ярко-розовым, обычные - белыми
                                        color: isSaved ? "#fa0567" : "#ffffff"
                                        font.bold: isSaved
                                        anchors.verticalCenter: parent.verticalCenter 
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (isSaved) {
                                                // Если сеть сохранена - подключаемся мгновенно одной командой без пароля
                                                connectWifiProc.command = ["nmcli", "connection", "up", ssidName];
                                                connectWifiProc.running = false;
                                                connectWifiProc.running = true;
                                                rootShell.updateSystemStatus();
                                            } else {
                                                // Если сеть новая - открываем ввод пароля
                                                passField.placeholderText = "Password for " + ssidName + "..."
                                                passField.visible = true
                                                passField.selectedSsid = ssidName
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TextField {
                        id: passField
                        property string selectedSsid: ""
                        width: parent.width
                        visible: false
                        placeholderText: "Enter Password..."
                        echoMode: TextInput.Password
                        color: "#ffffff"
                        background: Rectangle { color: "#2d2d2d"; border.color: "#fa0567"; radius: 4 }
                        
                        onVisibleChanged: {
                            if (visible) {
                                passField.forceActiveFocus();
                            }
                        }

                        onAccepted: {
                            connectWifiProc.command = ["nmcli", "dev", "wifi", "connect", selectedSsid, "password", text];
                            connectWifiProc.running = false;
                            connectWifiProc.running = true;
                            visible = false;
                            text = "";
                            rootShell.updateSystemStatus();
                        }
                    }
                }
                // --- ПОДМЕНЮ BLUETOOTH ---
                Column {
                    width: parent.width
                    spacing: 8
                    visible: btBtn.expanded

                    // ГЛОБАЛЬНЫЙ СТАТУС: Показывает, к чему конкретно вы подключены прямо сейчас
                    Text { 
                        text: rootShell.currentBluetooth === "Disconnected" ? "Status: Not Connected" : "Connected: " + rootShell.currentBluetooth
                        color: rootShell.currentBluetooth === "Disconnected" ? "#ffffff" : "#fa0567"
                        font.bold: rootShell.currentBluetooth !== "Disconnected"
                    }

                    Text { text: "Devices Nearby:"; color: "#ffffff"; font.bold: true }

                    ScrollView {
                        width: parent.width
                        height: bluetoothDevicesModel.count > 0 ? Math.min(bluetoothDevicesModel.count * 40, 120) : 0
                        clip: true

                        Column {
                            width: parent.width
                            spacing: 5

                            Repeater {
                                model: bluetoothDevicesModel
                                delegate: Rectangle {
                                    required property int index
                                    required property string deviceName
                                    required property string deviceMac
                                    required property bool isPaired
                                    required property bool isActive

                                    width: contentColumn.width; height: 35; radius: 4
                                    
                                    // Теперь булево свойство isActive отработает на 100% правильно
                                    color: isActive ? "#73022f" : (isPaired ? "#4d0220" : "#222222")
                                    border.color: (isActive || isPaired) ? "#fa0567" : "transparent"
                                    border.width: (isActive || isPaired) ? 1 : 0

                                    Text { 
                                        // Принудительно дописываем (Connected) к активной плашке в списке
                                        text: "     " + deviceName + (isActive ? " (Connected)" : "")
                                        color: (isActive || isPaired) ? "#fa0567" : "#ffffff"
                                        font.bold: isActive || isPaired
                                        anchors.verticalCenter: parent.verticalCenter 
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (deviceMac.length > 0) {
                                                connectBtProc.command = ["bash", "-c", "bluetoothctl trust " + deviceMac + " && bluetoothctl pair " + deviceMac + " && bluetoothctl connect " + deviceMac];
                                                connectBtProc.running = false;
                                                connectBtProc.running = true;
                                                console.log("Подключаемся к: " + deviceName);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }


                 // --- ПОЛЗУНОК ЗВУКА ---
                Column {
                    width: parent.width
                    spacing: 5
                    Text { text: "    Volume (" + rootShell.volumeValue + "%)"; color: "#ffffff" }
                    Slider {
                        width: parent.width
                        from: 0
                        to: 100
                        value: rootShell.volumeValue
                        onMoved: {
                            rootShell.volumeValue = Math.round(value);
                            setVolumeProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (rootShell.volumeValue / 100).toFixed(2)];
                            setVolumeProc.running = false;
                            setVolumeProc.running = true;
                        }
                    }
                }

                // --- ПОЛЗУНОК ЯРКОСТИ ---
                Column {
                    width: parent.width
                    spacing: 5
                    Text { text: "    Brightness (" + rootShell.brightnessValue + "%)"; color: "#ffffff" }
                    Slider {
                        width: parent.width
                        from: 0
                        to: 100
                        value: rootShell.brightnessValue
                        onMoved: {
                            rootShell.brightnessValue = Math.round(value);
                            setBrightnessProc.command = ["brightnessctl", "set", rootShell.brightnessValue + "%"];
                            setBrightnessProc.running = false;
                            setBrightnessProc.running = true;
                        }
                    }
                }
            }
        }
    }
}
