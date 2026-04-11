# --- LIST OF INSTALLED SHIT ---
choice=$(ls /usr/share/applications | sed 's/\.desktop//' | wofi --dmenu --prompt "Manage App:" --width 500 --height 600)

if [ -n "$choice" ]; then
    # --- SUB FCKNG MENU --- 
    action=$(echo -e "Launch\n Details\n Uninstall" | wofi --dmenu --prompt "$choice Actions:" --width 300 --height 250)
    
    case "$action" in
	*"Launch"*)
	    gtk-launch "$choice"
	    ;;
	*"Details"*)
	    foot -e bash -c "pacman -Q $choice; echo -e '\nPress Enter to close'; read"
	    ;;
	*"Uninstall"*)
	    foot -e sudo pacman -Rns "$choice"
	    notify-send "Caspian Manager" "$choice has been removed."
	    ;;
    esac
fi
