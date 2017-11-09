#!/bin/bash

wget -N -P /tmp http://192.168.2.2/coreos/coreos-install 
sleep 2
wget -N -P /tmp http://192.168.2.2/coreos/ignition.json 
sleep 2
sudo chmod +x /tmp/coreos-install
sudo /tmp/coreos-install -i /tmp/ignition.json -d /dev/sda
sudo reboot
