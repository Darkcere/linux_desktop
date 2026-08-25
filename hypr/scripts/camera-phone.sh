#!/usr/bin/env fish

# 1. Auto-detect phone connected via USB and enable wireless mode (bypasses pairing)
set usb_device (adb devices | grep -v "List of" | grep 'device$' | grep -v '\.' | head -n 1 | awk '{print $1}')

if test -n "$usb_device"
    echo "USB phone detected ($usb_device). Switching to wireless mode on port 5555..."
    adb -s $usb_device tcpip 5555
    sleep 2
    echo "Wireless mode active. You can now disconnect the USB cable."
end

# 2. Check if an active ADB connection exists
if not adb devices | string match -r -q 'device$'
    echo "No active ADB device detected."

    read -p "echo -n 'Do you need to pair via QR code? (y/N): '" need_qr

    if string match -i -q "y*" "$need_qr"
        if not command -v pairqr &> /dev/null
            echo "Error: 'pairqr' command not found."
            echo "Ensure Cargo bin is in your path with: fish_add_path ~/.cargo/bin"
        else
            echo "------------------------------------------------"
            echo "Scan this QR code on your phone:"
            echo "(Settings -> Developer options -> Wireless debugging -> Pair device with QR code)"
            echo "------------------------------------------------"
            pairqr
        end
    end

    read -p "echo -n 'Enter Phone IP address: '" ip
    read -p "echo -n 'Enter CONNECT PORT from Wireless Debugging main screen [default 5555]: '" port

    if test -z "$port"
        set port 5555
    end

    if test -n "$ip"
        echo "Connecting to $ip:$port..."
        timeout 10s adb connect "$ip:$port"
    end
end

# 3. Verify ADB connection before starting scrcpy
if not adb devices | string match -r -q 'device$'
    echo "Error: Could not establish ADB connection."
    exit 1
end

# 4. Launch scrcpy camera stream
echo "Starting scrcpy camera stream..."
scrcpy --video-source=camera \
       --camera-id=0 \
       --camera-size=1920x1080 \
       --video-bit-rate=20M \
       --v4l2-sink=/dev/video2 \
       --no-audio $argv
