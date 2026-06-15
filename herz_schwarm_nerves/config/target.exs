import Config

config :herz_schwarm, target: :rpi4

config :herz_schwarm, HerzSchwarmWeb.Endpoint, url: [host: "herz-schwarm.local"]

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

config :nerves_network, :ifname,
  "usb0": [mode: :dhcpd]

config :herz_schwarm, :uart_device, "/dev/ttyUSB0"
config :herz_schwarm, bridge_enabled: true
