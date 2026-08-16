import Config

config :herz_schwarm, target: :rpi4

config :herz_schwarm, HerzSchwarmWeb.Endpoint, url: [host: "herz-schwarm.local"]

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

config :nerves_network, :ifname,
  usb0: [mode: :dhcpd]

# On the Raspberry Pi, the ESP32-Bridge typically shows up as ttyUSB0
# (USB-serial bridge like CH340/CP2102) when wired via the Pi's USB-A port.
# For native USB-CDC on ESP32-S3, use ttyACM0.
config :herz_schwarm, :uart_device, "/dev/ttyUSB0"
config :herz_schwarm, bridge_enabled: true

# Persistente Nerves-Partition (uebersteht Reboots) statt tmp/
config :herz_schwarm, :firmware_dir, "/root/firmware"
