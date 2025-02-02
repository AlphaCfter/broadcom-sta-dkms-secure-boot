# Manual Enrollment

- First ensure the secure boot is turned on by executing. Turn on secure boot via UEFI firmware if not enabled 

   `sudo mokutil --sb-state`

- Make sure you got the binaries installed on your linux machine

    `sudo apt install broadcom-wl`  
    `sudo apt install bcmwl-kernel-source`  
    `sudo apt install broadcom-sta-dkms`
- Make sure you have your kernel headers installed as well

  `sudo apt install linux-headers-$(uname -r)`

- Locate your kernel module in the /lib directory over root and move them over to Desktop or Documents
    
    `sudo mv /lib/modules/$(uname -r)/updates/dkms/wl.ko.zst ~/Desktop && cd ~/Desktop`

- The latest package in `broadcom-sta-dkms` typically ships with the .ko filed under zst compression but the `bcmwl-kernel-source` till date ships directly with the .ko file. Decompress the file and extract the wl.ko file
    `zstd -d wl.ko.zst -o wl.ko`

-  Generate an RSA private key and derive a public key more like a certificate (X.509)

   `openssl req -new -x509 -newkey rsa:2048 -keyout key.priv -outform DER -out key.der -nodes -days 36500 -subj "/CN=broadcom-sta/"`

- Register your public key generated with secure boot (Signature Database) and provide a strong passkey via MOKutility

  `sudo mokutil --import key.der`

- Sign your kernel module with both they keys using SHA256 key via Linux headers

  `sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 key.priv key.der wl.ko`


- Compress the file back into .zhc

    `zstd -c wl.ko > wl.ko.zst`

- Move the file back to the /lib directory

    `sudo cp wl.ko.zst /lib/modules/$(uname -r)/updates/dkms`

- Reboot and enter your password you've created and make sure the secure boot is turned on

    `sudo systemctl reboot --firmware`

- You've made it 🎉. The driver must be up and functional as usual


**NOTE:**

- The public keys are displayed over your desktop. **Keep the keys SAFE** so you can **sign other modules**. Loosing these keys will have to **re-Enroll a new key** which can be quiet stressfull.
- When a new kernel module is patched via DKMS or Depmod, note the directory of the module via the command line.
- Any binaries with the signed keys in the Signature Database is **allowed to boot**
- Compromising this key can lead to kernel patches which can be booted via the secure boot


# Script Enrollment

You could clone the current project by   

`git clone https://github.com/AlphaCfter/broadcom-sta-dkms-secure-boot.git`  

`cd broadcom-sta-dkms-secure-boot`

`chmod +x script.sh`

`sudo ./script.sh`

# Broadcom Drivers

- Linux being an opensource project does allows free distribution, modification and  remodification under the GNU General Public License (GPL)

- The Linux mainline kernel includes open-source kernel modules suitable for plug-and-play functionality; however, some drivers do not support certain hardware and are considered **Non-Free Drivers**

- Broadcom WiFi cards which is considered as a Non-Free Drivers, need properitery pieces of code to function on the operating system. One such package is `broadcom-sta-dkms`,`broadcom-wl` and `bcmwl-kernel-source`. These drivers are simply not supported by opensource packages like `b43` or `brcmsmac`

- `lsblk` would show up all the listed USB probes on your computer (Mine in this case **BCM20702A0** which is **Almost NOT SUPPORTED without a properitery support from Broadcom**)

- Such packages would come with built in certificates(X.509 certificates) which are signed with vendors keys which automatically boots with the secure boot turned on.

- Secure Boot is a security feature that ensures only trusted (signed) software is allowed to run during the boot process. It checks that the bootloader, kernel, and other essential components are signed with a trusted cryptographic key. This is primarily intended to prevent malware from running at boot time.

![alt text](https://i0.wp.com/theembeddedkit.io/wp-content/uploads/2023/10/Secure-boot-secure-by-design-Linux.png)
*Courtesy: https://theembeddedkit.io*

- When secureboot is turned on, the system verifies and only allows those drivers with a valid certificates or signature (Eg Microsoft, MOK)

- Microsoft, as the creator of Windows, uses digital signatures to ensure that only trusted software is allowed to load during the boot process. Microsoft has a private key that it keeps secret. This key is used to sign softwares. The public key is distributed and stored in the computer’s UEFI firmware. This key is used to verify the signature on the software that’s trying to run during the boot process.

- When the system boots, it checks the digital signature on the software. If the signature is valid and matches Microsoft’s public key, the software is trusted, and the system continues to boot. If the signature doesn’t match, Secure Boot will block it from running to protect your system.
## Acknowledgements

 - [How to enable secure boot in embedded systems](https://theembeddedkit.io/blog/enable-secure-boot-in-embedded-systems/)
 - [Youtube video explaining TPM and Secure Boot](https://www.youtube.com/watch?v=WRFnOh_pqX8)
 - [AskUbuntu](https://askubuntu.com/search?q=broadcom+secureboot)
- [Linux Hardware Database](https://linux-hardware.org/)
- [Arch Wiki](https://wiki.archlinux.org/title/Broadcom_wireless)
- [Redditor: Candyboy23](https://www.reddit.com/r/Ubuntu/comments/1g0vmu5/solution_after_2410_upgrade_if_your_wifi_not/)
- [Broadcom Packages](https://www.broadcom.com/site-search?filters[pages][content_type][type]=and&filters[pages][content_type][values][]=Downloads&page=1&per_page=10&q=802.11%20linux%20sta%20wireless%20driver)








## Documentation

[Documentation](https://github.com/clearlinux/clear-linux-documentation/blob/master/source/tutorials/broadcom.rst)

