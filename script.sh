#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "Detecting distribution"
    if grep -q -i 'debian' /etc/os-release; then
    echo "This is a Debian-based system."
else
    echo ""
    echo "This is not a Debian-based system. This script only works for debian bases systems"
    exit 1
fi
    echo ""
    echo "Script requires elevated (sudo) privileges."
    echo "Do you want to run this script in (sudo) mode (y/n)?"
    read CHOICE
    echo ""
    if [[ "$CHOICE" == "y" || "$CHOICE" == "Y" ]]; then
        sudo "$0" "$@"
        exit 0
    else
        echo "Exiting script."
        exit 1
    fi
fi

execute() {
    echo ""	
    echo "Detected: $OSTYPE"
    echo ""
    echo "Release: $(lsb_release -a)"
    echo ""
    echo "Kernel: $(uname -r)"
    echo ""
    
    #Hardcoded packages
    NAME="broadcom-sta-dkms"
    NAME2="bcmwl-kernel-source"

    # Install mokutil if not installed
    sudo apt install -y mokutil
    echo "Let's check your Secure Boot status..."

    if command -v mokutil &>/dev/null; then
        secure_boot_status=$(mokutil --sb-state)
        echo "$secure_boot_status"

        if [[ "$secure_boot_status" == *"SecureBoot enabled"* ]]; then
            echo "Secure Boot is enabled."
        else
            echo "Secure Boot is disabled."
        fi
    else
        echo "mokutil is not installed. Cannot check Secure Boot status."
    fi
    
    # Check if Broadcom packages are installed
    if dpkg -s $NAME &>/dev/null || dpkg -s $NAME2 &>/dev/null; then
        echo "$NAME or $NAME2 packages are installed."
    else
        echo "$NAME nor $NAME2 are not installed."
        echo "Do you want to install them (y/n)?"
        read CHOICE
        if [[ "$CHOICE" == "y" || "$CHOICE" == "Y" ]]; then
            echo "Installing packages..."
            sudo apt-get update
            sudo ubuntu-drivers install
            if [ $? -eq 0 ]; then
                echo "Installation successful."
            else
                echo "Error installing packages."
                exit 1
            fi
            sudo apt install linux-headers-$(uname -r) -y

            # Process kernel module files
            for file in /lib/modules/$(uname -r)/updates/dkms/*.zst; do
                if [ -f "$file" ]; then
                    echo "Found zst file: $file"
                    sudo mv /lib/modules/$(uname -r)/updates/dkms/wl.ko.zst ~/Desktop
                    cd ~/Desktop
                    zstd -d wl.ko.zst -o wl.ko
                    echo ""
                    echo "Generating RSA keys..."
                    openssl req -new -x509 -newkey rsa:2048 -keyout key.priv -outform DER -out key.der -nodes -days 36500 -subj "/CN=broadcom-sta/"
                    echo "Generated RSA Keys."
                    echo ""
                    echo "Enrolling key via MOK. Enter a strong password."
                    sudo mokutil --import key.der
                    echo "Signing kernel modules with the generated keys."
                    sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 key.priv key.der wl.ko
                    echo "Signed kernel modules with private and public keys."
                    echo ""
                    zstd -c wl.ko > wl.ko.zst
                    sudo cp wl.ko.zst /lib/modules/$(uname -r)/updates/dkms
                    echo "Process completed. Restart your system and enroll your module by entering the password."
                    echo "-----------------------------------------------------------------------------------------"
                    echo "Since MOK (Machine Owner Key) key is enrolled, KEEP THE KEY.priv SAFE if your concerned about security"
                    echo ""
                    sleep 3
                    echo "Anybody can allow any kernel signed module with your .priv key and make sure you keep it safe"
                    echo ""
                    sleep 3
                    echo "Deleting they can be an option but YOU CANNOT SIGN ANYMORE NEW MODULES which are installed (eg Vbox modules)"
                    echo ""
                    sleep 3
                    echo "Loosing the key can result in enrollment of new key again"
                    echo ""
                    sleep 3
                    echo "-----------------------------------------------------------------------------------------"
                fi
            done
        fi
    fi
}

execute

