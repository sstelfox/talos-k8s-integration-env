#!/usr/bin/env sh

sudo killall -s SIGTERM talosctl
sudo killall -s SIGTERM swtpm

echo 'Manually clean up network!'

#ip link -> find the link name
#ip link del talos443c8fb1
