# Experimental macOS Port of https://github.com/mart1nro/joycontrol

Adapting joycontrol's usage of bluez to macOS IOBluetooth/CoreBluetooth with support from https://github.com/PureSwift/BluetoothDarwin for lower-level API access.

## Getting Started

1. Run from Xcode
2. Toggle ```Allow pairing``` on
3. Ensure Switch is at ```Controllers``` -> ```Change Grip/Order``` screen
4. After a successful connection at the ```Change Grip/Order``` screen, click ```Connect``` in the UI to establish a permanent connection with the Nintendo Switch

## Troubleshooting

* If the Switch stops attempting to connect in the ```Change Grip/Order``` screen, try resetting the bluetooth service in macOS:

```
sudo launchctl stop com.apple.bluetoothd && launchctl start com.apple.bluetoothd
```

## TODO/Known Issues

- [x] __UPDATE:__ This appers to only happen on the Change Grip/Order screen. Once the initial connection is made there, exit the menu and then click ```Connect``` in the UI. ~~Bluetooth controller appears to initiate a disconnect after everything is running smoothly. It's still unclear why the following happens (log captured with Packet Logger from Xcode Tools):~~

```
Feb 09 15:30:38.153
Note
0x0000
Attempt to close L2CAP Channel 0x0042 for connection handle 0x0020 from process "Unknown (0) (IOBluetoothDeviceUserClient::closeConnectionWL())"
```

- [ ] Extract joycontrol-specific logic into a Swift package
- [ ] Only Pro Controller is emulated at the moment
- [ ] Input Report frequency is limited at the moment
- [ ] Add control stick support to UI