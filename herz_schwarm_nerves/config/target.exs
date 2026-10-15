import Config

config :herz_schwarm, target: :rpi4

config :herz_schwarm, HerzSchwarmWeb.Endpoint, url: [host: "herz-schwarm.local"]

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

config :nerves_network, :ifname,
  usb0: [mode: :dhcpd]

# Bridge-Port wird zur Laufzeit erkannt (ttyUSB* bei CH340/CP2102, ttyACM* bei
# nativem USB wie ESP32-C3/S3/C6). Fester Port nur bei Bedarf:
# config :herz_schwarm, :uart_device, "/dev/ttyACM0"
config :herz_schwarm, bridge_enabled: true
