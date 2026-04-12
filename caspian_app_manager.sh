# --- LIST OF INSTALLED SHIT ---
choice=$(wofi --show drun --prompt "Caspian Manager" --width 600 --height 500 --allow-images --style ~/dotfiles/.config/wofi/style.css)

if [ -n "$choice" ]; then
    app_name=$(echo "$choice" | awk '{print $2}')

    action=$(echo -e "Launch\nDetails\nUnistall" | wofi --demu --prompt "Actions for $app_name" --width 300 --height 250)

    case "$action" in
	*"Launch"*) gtk-launch "$app_name" ;;
	*"Details"*) foot -e bash -c "pacman -Qi $app_name; echo; read -p 'Press Enter To Exit...'" ;;
	*"Unistall"*) foot -e sudo pacman -Rns "$app_name" ;;
    esac
fi
