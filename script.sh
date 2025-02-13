#!/bin/bash

USERNAME=$USER
DISTRO=$(lsb_release -i | awk -F: '{print $2}' | xargs)

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo ""
        echo "Detecting distribution..."
        
        # Check if the system is Debian-based
        if grep -q -i 'debian' /etc/os-release; then
            echo "This is a Debian-based system."
        else
            echo ""
            echo "This is not a Debian-based system. This script only works for Debian-based systems."
            exit 1
        fi
    fi
}

# Function to execute the main logic
execute() {
    echo ""
    echo "Detected: $OSTYPE"
    echo ""
    echo "Release: $(lsb_release -a)"
    echo ""
    echo "Kernel: $(uname -r)"
    echo ""

    # Hardcoded package names
    local NAME="broadcom-sta-dkms"
    local NAME2="bcmwl-kernel-source"

    if [[ "$DISTRO" == 'Deepin' ]]; then
        echo ""
        echo "Deepin distro detected"

        # Remove immutable support
        sudo deepin-immutable-ctl disable-system-protect enable 

        sudo apt install $NAME

        # sudo apt-get --reinstall install bcmwl-kernel-source
        sudo modprobe -r b43 ssb wl brcmfmac brcmsmac bcma #Blacklist open-source drivers
        sudo modprobe wl #Load wl.ko module
        sudo deepin-immutable-ctl disable-system-protect disable #Enable integrity protection
        echo ""
        echo "System Restart is recommended to take changes"
        sudo systemctl reboot
        
    fi
    
    if [[ "$DISTRO" == 'Fedora' ]]; then
        echo ""
        echo "Fedora detected"

        # Add Fastest mirror via DNF conf
        sudo sed -i '3i fastestmirror=True' /etc/dnf/dnf.conf

        sudo dnf update && sudo dnf upgrade

        
        sudo dnf install kernel-devel kernel-headers #Headers
        sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm #Grab a copy of the non free package
        sudo mv /usr/lib/modules/$(uname -r)/extra/wl/wl.ko.xz ~/Desktop #Move to a writable path
        cd ~/Desktop
        tar wl.ko.xz	#Decompress the xz file
        rm -rf wl.ko.xz #Remove the xz file to prevent from duplication
        sudo /usr/src/kernels/$(uname -r)/scripts/sign-file sha256 key.priv key.der wl.ko
        sudo sh -c "sudo xz wl.ko"
        sudo mv wl.ko.xz /usr/lib/modules/$(uname -r)/extra/wl	#Move back to modules
        sudo mokutil --import key.der #Import key
        echo ""
        echo "System Restart is recommended to take changes"
        sudo systemctl reboot
        
    fi
    
    if [[ "$DISTRO" == 'LinuxMint' ]]; then
        echo ""
        echo "Linux Mint detected"

        echo ""
        echo "Driver installed"
        echo ""
        sudo apt install $NAME
        echo ""
        echo "Automatic enrollment"
        sudo /bin/sh /sbin/update-secureboot-policy --enroll-key
    fi

    if [[ "$DISTRO" == 'Ubuntu' ]]; then
        echo ""
        echo "Ubuntu detected"
        echo ""
        
        # Install mokutil
        echo "Installing mokutil"
        echo ""
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
            echo "Mokutil is not installed. Cannot check Secure Boot status."
        fi

        # Install broadcom-sta-dkms
        echo ""
        echo -n "Should I install broadcom-sta-dkms? (y/n): "
        read CHOICE

        if [[ "$CHOICE" == "y" || "$CHOICE" == "Y" ]]; then
            echo ""
            echo "Performing full system upgrade..."
            sleep 2
            sudo apt-get update && sudo apt-get upgrade -y
            echo ""
            echo "System upgrade completed."
            sleep 2
            echo ""
            echo "Installing dependencies..."
            echo ""
            sleep 2
            sudo apt install -y broadcom-sta-dkms linux-headers-$(uname -r)

            if [ $? -eq 0 ]; then
                echo ""
                echo "Installation successful."
                sleep 2
                # Move the module to Desktop
                sudo cp /lib/modules/$(uname -r)/updates/dkms/wl.ko.zst /home/$USERNAME/Desktop
                if [ $? -eq 0 ]; then
                    echo ""
                    echo "Moved module to Desktop."
                    sleep 2

                    # Decompress the .zst archive
                    cd /home/$USERNAME/Desktop
                    zstd -d wl.ko.zst -o wl.ko
                    if [ $? -eq 0 ]; then
                        echo ""
                        echo "Decompressed ZST archive."
                        sleep 2

                        # Generate RSA keys for signing
                        echo ""
                        echo "Generating RSA keys..."
                        openssl req -new -x509 -newkey rsa:2048 -keyout key.priv -outform DER -out key.der -nodes -days 36500 -subj "/CN=broadcom-sta/"
                        if [ $? -eq 0 ]; then
                            echo ""
                            echo "Generated RSA Keys."
                            sleep 2

                            # Enroll key via MOK
                            echo ""
                            echo "Enrolling key via MOK. Enter a strong password."
                            sudo mokutil --import key.der
                            if [ $? -eq 0 ]; then
                                echo ""
                                echo "Module imported via Mokutil."
                                sleep 2

                                # Sign the kernel module with generated keys
                                echo "Signing kernel modules with the generated keys."
                                sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 key.priv key.der wl.ko
                                if [ $? -eq 0 ]; then
                                    echo ""
                                    echo "Signed kernel module successfully."
                                    sleep 2

                                    # Repack the archive
                                    echo ""
                                    echo "Repacking archive..."
                                    sudo sh -c "zstd -c wl.ko > wl.ko.zst"
                                    if [ $? -eq 0 ]; then
                                        echo ""
                                        echo "Archive repacked."
                                        sleep 2

                                        # Copy the archive back to the modules directory
                                        echo "Copying the archive back to the modules directory..."
                                        sudo rm /lib/modules/$(uname -r)/updates/dkms/wl.ko.zst
                                        sudo cp wl.ko.zst /lib/modules/$(uname -r)/updates/dkms
                                        sudo rm -rf /home/$USERNAME/Desktop/wl.ko.zst /home/$USERNAME/Desktop/wl.ko /home/$USERNAME/Desktop/key.der
                                        if [ $? -eq 0 ]; then
                                            echo ""
                                            echo "Copied the archive back to modules."
                                            sleep 2

                                            # Final instructions
                                            echo ""
                                            echo "Process completed. Restart your system and enroll your module by entering the password."
                                            echo ""
                                            echo "-------------------------------------------------"
                                            echo "Since MOK (Machine Owner Key) is enrolled, KEEP the key.priv file SAFE if you are concerned about security."
                                            echo ""
                                            echo "Anyone with access to your .priv key can sign kernel modules, so protect it carefully!"
                                            echo ""
                                            echo "Losing the key will require enrolling a new key."
                                            echo "-----------------------------------------------------------------------------------------"
                                        else
                                            echo "Error copying archive back to modules directory."
                                        fi
                                    else
                                        echo "Error repacking archive."
                                    fi
                                else
                                    echo "Error signing kernel module."
                                fi
                            else
                                echo "Error importing MOK key."
                            fi
                        else
                            echo "Error generating RSA keys."
                        fi
                    else
                        echo "Error decompressing the ZST archive."
                    fi
                else
                    echo "Error moving module to Desktop."
                fi
            else
                echo "Error installing broadcom-sta-dkms or linux headers."
                exit 1
            fi
        fi
    fi
}

# Main script execution
check_root
execute
