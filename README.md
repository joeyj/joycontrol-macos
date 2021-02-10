# Experimental macOS Port of https://github.com/mart1nro/joycontrol

Adapting joycontrol's usage of bluez to macOS IOBluetooth/CoreBluetooth with support from https://github.com/PureSwift/BluetoothDarwin for lower-level API access.

## Getting Started

1. Run from Xcode
2. Toggle "Allow pairing" on
3. Ensure Switch is at Controllers -> Change Grip/Order screen

## Troubleshooting

* If the Switch stops attempting to connect, try resetting the bluetooth service in macOS:

```
sudo launchctl stop com.apple.bluetoothd && launchctl start com.apple.bluetoothd
```

## TODO/Known Issues

* Bluetooth controller appears to initiate a disconnect after everything is running smoothly. It's still unclear why the following happens (log captured with Packet Logger from Xcode Tools):

```
Feb 09 15:30:38.153  Note             0x0000                     Attempt to close L2CAP Channel 0x0042 for connection handle 0x0020 from process "Unknown (0) (IOBluetoothDeviceUserClient::closeConnectionWL())"
```
* Extract joycontrol-specific logic into a Swift package
* Only Pro Controller is emulated at the moment
