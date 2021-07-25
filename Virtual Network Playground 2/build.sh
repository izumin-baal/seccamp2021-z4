#!/bin/bash
if [[ `whoami` != "root" ]]
then
    echo "rootで実行してください"
    exit 1
fi
#
# FRRインストール
#
# https://deb.frrouting.org/
echo "!FRR install!"
curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
FRRVER="frr-stable"
echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list
sudo apt update && sudo apt install frr frr-pythontools

#
# add netns
#
echo "!add netns!"
ip netns add C1
ip netns add C2
ip netns add C3
ip netns add C4
ip netns add R1
ip netns add R2
ip netns add R3
#
# add interfaces
#
echo "!add interfaces!"
ip link add C1-R1 type veth peer name R1-C1
ip link add C2-R1 type veth peer name R1-C2
ip link add R1-R2 type veth peer name R2-R1
ip link add C3-R2 type veth peer name R2-C3
ip link add C4-R2 type veth peer name R2-C4
ip link add R1-R3 type veth peer name R3-R1
ip link add R2-R3 type veth peer name R3-R2
#
# add link
#
echo "!add links!"
ip link set R1-C1 netns R1 up
ip link set R1-C2 netns R1 up
ip link set R1-R2 netns R1 up
ip link set R1-R3 netns R1 up
ip link set R2-C3 netns R2 up
ip link set R2-C4 netns R2 up
ip link set R2-R1 netns R2 up
ip link set R2-R3 netns R2 up
ip link set R3-R1 netns R3 up
ip link set R3-R2 netns R3 up
ip link set C1-R1 netns C1 up
ip link set C2-R1 netns C2 up
ip link set C3-R2 netns C3 up
ip link set C4-R2 netns C4 up
#
# add IP address
#
echo "!add IP address!"
ip netns exec C1 ip addr add 10.1.0.2/24 dev C1-R1
ip netns exec C2 ip addr add 10.2.0.2/24 dev C2-R1
ip netns exec C3 ip addr add 10.3.0.2/24 dev C3-R2
ip netns exec C4 ip addr add 10.4.0.2/24 dev C4-R2
ip netns exec R1 ip addr add 10.1.0.1/24 dev R1-C1
ip netns exec R1 ip addr add 10.2.0.1/24 dev R1-C2
ip netns exec R2 ip addr add 10.3.0.1/24 dev R2-C3
ip netns exec R2 ip addr add 10.4.0.1/24 dev R2-C4
ip netns exec R1 ip addr add 10.255.1.1/24 dev R1-R2
ip netns exec R2 ip addr add 10.255.1.2/24 dev R2-R1
ip netns exec R1 ip addr add 10.255.2.1/24 dev R1-R3
ip netns exec R3 ip addr add 10.255.2.2/24 dev R3-R1
ip netns exec R2 ip addr add 10.255.3.1/24 dev R2-R3
ip netns exec R3 ip addr add 10.255.3.2/24 dev R3-R2
ip netns exec R1 ip addr add 1.1.1.1/32 dev lo label lo:2
ip netns exec R2 ip addr add 2.2.2.2/32 dev lo label lo:2
ip netns exec R3 ip addr add 3.3.3.3/32 dev lo label lo:2
#
# Routing settings
#
echo "!route setting!"
ip netns exec C1 ip route add default via 10.1.0.1
ip netns exec C2 ip route add default via 10.2.0.1
ip netns exec C3 ip route add default via 10.3.0.1
ip netns exec C4 ip route add default via 10.4.0.1
ip netns exec R1 ip route add 3.3.3.3/32 via 10.255.2.2
ip netns exec R1 ip route add 2.2.2.2/32 via 10.255.1.2
ip netns exec R1 ip route add 10.3.0.0/24 via 10.255.1.2
ip netns exec R1 ip route add 10.4.0.0/24 via 10.255.1.2
ip netns exec R1 ip route add 10.255.3.0/24 nexthop via 10.255.1.2 weight 1 nexthop via 10.255.2.2 weight 1
ip netns exec R2 ip route add 3.3.3.3/32 via 10.255.3.2
ip netns exec R2 ip route add 1.1.1.1/32 via 10.255.1.1
ip netns exec R2 ip route add 10.1.0.0/24 via 10.255.1.1
ip netns exec R2 ip route add 10.2.0.0/24 via 10.255.1.1
ip netns exec R2 ip route add 10.255.2.0/24 nexthop via 10.255.1.1 weight 1 nexthop via 10.255.3.2 weight 1
ip netns exec R3 ip route add 1.1.1.1/32 via 10.255.2.1
ip netns exec R3 ip route add 2.2.2.2/32 via 10.255.3.1
ip netns exec R3 ip route add 10.1.0.0/24 via 10.255.2.1
ip netns exec R3 ip route add 10.2.0.0/24 via 10.255.2.1
ip netns exec R3 ip route add 10.3.0.0/24 via 10.255.3.1
ip netns exec R3 ip route add 10.4.0.0/24 via 10.255.3.1
ip netns exec R3 ip route add 10.255.1.0/24 nexthop via 10.255.2.1 weight 1 nexthop via 10.255.3.1 weight 1
#
# routingの有効化
#
ip netns exec R1 sysctl -w net.ipv4.ip_forward=1
ip netns exec R2 sysctl -w net.ipv4.ip_forward=1
ip netns exec R3 sysctl -w net.ipv4.ip_forward=1
#
# 
#
echo "Done!"
