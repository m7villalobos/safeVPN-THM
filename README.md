# TryHackMe Safe VPN Access

This document explains a custom IPTables configuration script designed to improve the security of your TryHackMe VPN connection. The script restricts traffic on the `tun0` interface, allowing access only to a specific IP address.

**Key Improvements:**

- **Simplified Script:** The script has been streamlined for easier use in TryHackMe environments. It assumes you receive unique IPs for both the VPN server (`remote`) and target machines.
- **Enhanced Automation:** The script now automates many steps, such as detecting the default network interface and extracting the VPN server IP and port from your `.ovpn` file.
- **Enhanced Security:** The script maintains IPv6 blocking and includes improved handling of missing backup files, ensuring a more secure and reliable environment.
- **Clearer Instructions:** The script's comments and instructions are now in English for broader usability.

---

## Features

- **Target IP Specificity**: Limits traffic on `tun0` to a single, user-defined IP address.
- **Automatic VPN Detection**: Extracts the VPN server's IP and port from your `.ovpn` file dynamically.
- **Robust Error Handling**: Validates the provided IP address and ensures the script runs smoothly.
- **Firewall Rule Management**: Includes a `--flush` option to **restore the previous iptables configuration**.
- **IPv6 Blocking**: Enhances security by dropping all IPv6 traffic (assuming an IPv4-based VPN).

---

## Requirements

- A valid OpenVPN `.ovpn` configuration file.
- `sudo` privileges to run the script (iptables requires superuser access).

---

## Setup

1. **Clone or Download:** Obtain the script and save it locally.
2. **Edit Script (Optional):**
   - Open the script using a text editor (e.g., `nano safevpn.sh`).
   - If your `.ovpn` file is not named `YourFile.ovpn`, update the `OVPN_FILE` variable accordingly. This step is only necessary if your `.ovpn` file has a different name.

3. **Make Executable:** Grant the script execution permissions:
   ```bash
   chmod +x safevpn.sh
   ```

---

## Usage

### Allow Traffic to a Specific Machine:

Run the script with the target machine's IP address:

```bash
sudo ./safevpn.sh <IP_ADDRESS>
```

**Example:**

```bash
sudo ./safevpn.sh 10.10.10.10
```

### Flushing and Restoring Rules

The script provides enhanced flexibility for clearing firewall rules:

- **Full Flush (Recommended):**  
  Use `--flush` to perform a complete flush of all iptables rules applied by the script. This option does not attempt to restore previous rules and is the simplest method.

  Example:
  ```bash
  sudo ./safevpn.sh --flush
  ```

- **Restore Previous Configuration (If Available):**  
  Use `--flush restore` to attempt restoring your previous iptables configuration from backup files saved during the last run. If no backups are found, you'll be prompted to do a full flush instead.

  Example:
  ```bash
  sudo ./safevpn.sh --flush restore
  ```

This added flexibility helps ensure a smoother return to your original firewall settings if needed. If you prefer the original behavior—where previous rules are restored if possible—simply use `--flush restore`. For a clean slate, stick to `--flush`.


---

## Notes

- The script blocks all traffic not explicitly allowed, enhancing the security of the tun0 interface.
- IPv6 traffic is dropped by default, assuming an IPv4-based VPN environment.
- The `--flush` option now offers two approaches:
  - **Full Flush (Recommended):** Running `--flush` without arguments clears all firewall rules without attempting restoration.
  - **Restore Previous Configuration:** Using `--flush restore` attempts to restore the previous iptables configuration from backup files. If no backups are found, you will be prompted to perform a full flush.
- These changes provide more control and transparency when reverting to your original firewall state.


---

## Credits

This script is based on the original work by **Nisrin Ahmed aka Wh1teDrvg0n**, with additional enhancements for functionality, usability, and dynamic VPN server configuration by **Miguel Ángel Villalobos**.

---

## Troubleshooting

1. **VPN Connection Issues:**
   - Verify the `.ovpn` file path is correct in the script (if modified).
   - Check if the VPN server's IP and port are reachable.
   - Use `sudo iptables -L -n -v` to view applied rules.

2. **Script Execution Errors:**
   - Ensure the script has execution permissions (`chmod +x safevpn.sh`).
   - Run the script with `sudo` for proper privileges.

3. **Unexpected Traffic Blocking:**
   - Double-check that the correct IP address was specified for the target machine.
