choice=$(nmcli -t -f "SSID,BARS,SECURITY" device wifi list | sed 's/:/ - /g' | wofi --dmenu --prompt "Network Manager:" --width 600 --height 500 --style ~/dotfiles/.config/wofi/style.css)

if [ -n "$choice" ]; then
    SSID=$(echo "$choice" | awk -F " - " '{print $1}')

    action=$(echo -e "Connect\nDetails\nDisconnect" | wofi --dmenu --prompt "Manage $SSID:" --width 300 --height 250)

    case "$action" in
	*"Connect"*)
	    nmcli connection delete "$SSID" > /dev/null 2>&1
	    security=$(nmcli -t -f "SSID,SECURITY" device wifi list | grep "^$SSID" | awk -F: '{print $2}')

	    if [[ "$security" == *"802.1X"* ]]; then
		user=$(wofi --dmenu --prompt "Login:")
		pass=$(wofi --dmenu --prompt "Password:" --password)
	        nmcli device wifi connect "$SSID" 802-1x.identity "$user" 802-1x.password "$pass" > /tmp/wifi_res 2>&1 &
	    else
	        pass=$(wofi --dmenu --prompt "Password for $SSID:" --password)
	        nmcli device wifi connect "$SSID" password "$pass" > /tmp/wifi_res 2>&1 &
	    fi

	    CONN_PID=&!

	    foot --title="Connecting" --window-size-chars 40x5 bash -c "
		spinner='|/-\\'
		while kill -0 $CONN_PID 2>/dev/null; do
		    for i in {0..3}; do
			echo -ne \"\\r[\${spinner:\$i:1}] Connecting to $SSID...\"
			sleep 0.1
		    done
		done
	    " &
	    wait $CONN_PID

	    if [ $? -eq 0 ]; then
		notify-send "Network Manager" "Connected to $SSID"
	    else
		ERROR_MSG=$(cat /tmp/wifi_res)
		notify-send -u critical "Connection Failed" "Disconnected"
	    fi
	    ;;

	*"Details"*)
	    foot -e bash -c "nmcli -p device show wlan0; echo; nmcli -p device wifi list | grep '$SSID'; read -p 'Press Enter...'"
	    ;;

	*Disconnect*)
	    nmcli device disconnect wlan0
	    notify-send "Network Manager" "Disconnected from $SSID"
	    ;;

    esac
fi
