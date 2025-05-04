# The following is a guide for debian 12 (bookworm), it should work on all modern distros and the concepts will apply to any OS of your choosing
# What this will do is create a dual-stack (so ipv4 and ipv6) docker network you can add to your containers and add NAT for this network so any requests are mapped to a random IP from the specified range
# NOTE: Due to how linux does SNAT (source: http://blog.asiantuntijakaveri.fi/2017/03/linux-snat-with-per-connection-source.html) the outgoing ip SNAT picks is "sticky", linux hashes the source ip and uses that to pick the outgoing IP, in the usual /64 setup it seems to switch between 2 outgoing ips
#       The blog post links a kernel patch to change this, but I don't want to get into patching the kernel (here, or at all to be honest).
#       I have thought of a workaround to try, adding many SNAT rules with a sub-set of the ip range for each source port (as those should be random), then you'd get ~40k (rough untested guesstimate) ips per container, but I don't know if that performs or works at all
## CONFIG
# specify which ip range to use
#    auto detect ipv6 network (jank alert! there's a /64 hard-coded! verify this works by running the command in the ` before using. or just dont :| )
#IP6BLOCK=`ip addr show | grep inet6 | grep -vE ' f[de][0-9a-f]{2}:' | grep /64 | head -n1 | sed -E "s/\s*inet6\s*([0-9a-f:]*?)::1\/64 scope global\s*/\1/"`
# or manually (recommended):
IP6BLOCK="fd53:29cd:5652:18ac" # this is a placeholder!
# the default _START and _END values assume a /64 and the host is using $IP6BLOCK::1, so $IP6BLOCK::2 up to the end can be used for SNAT
IP6SNAT_START="::2" # start snat at $IP6BLOCK$IP6SNAT_START
IP6SNAT_END=":ffff:ffff:ffff:ffff" # end snat at $IP6BLOCK$IP6SNAT_END
# private ranges to use for docker container network
PRIVATE_V6="fd61:a12b:f6ed:f920::/64"
PRIVATE_V4="172.19.0.0/16"
# If this is a switched network, the host will need to respond to neighbour solicitations for the whole ipv6 network
# This is not needed for hetzner, but is for OVH and Scaleway (leaving it on regardless won't cause issues though)
SWITCHED_NETWORK=1
# INTERFACE is only used for switched networks, auto detect should be pretty solid unless you have multiple actual network interfaces
# if auto does not work specify it manually
INTERFACE=`ip route | grep default | sed -E "s/.*dev ([^ ]+).*/\1/"`
# or manual:
#INTERFACE="eth0"
IP6BLOCK_SIZE="64" # network size, this is only used for switched networks
## END CONFIG

# on a fresh VM you might have to `apt update && apt upgrade -y && reboot` first (hetzner ones ship with something that makes iptables not work until after upgrade+reboot on debian 12 currently)

# get the system updated
apt update && apt upgrade -y
# install docker (& apparmor which seems to be required for docker to function)
# if the debian-provided one becomes too old, it might be worth considering dockers repo: https://docs.docker.com/engine/install/debian/
apt install docker.io apparmor -y
# docker config, the log stuff isn't needed but should be configured anyways to limit log disk space
echo '{
  "experimental": true,
  "ip6tables": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  }
}' > /etc/docker/daemon.json
systemctl restart docker

# create a docker network using private v4&v6 range since we're nat'ing below
docker network create --ipv6 -o "com.docker.network.bridge.enable_ip_masquerade=false" --subnet $PRIVATE_V6 --subnet $PRIVATE_V4 ip6net

# add NAT rules for v4 & v6
# ipv4: 
#    if you have multiple ipv4's you can also do SNAT here by replacing "-j MASQUERADE" with "-j SNAT --to-source IPV4_START-IPV4_END"
iptables -t nat -A POSTROUTING -s $PRIVATE_V4 ! -o docker0 -j MASQUERADE
# IPv6 SNAT to make it use a random ip from the whole range:
ip6tables -t nat -A POSTROUTING -s "$PRIVATE_V6" -j SNAT --to-source "$IP6BLOCK$IP6SNAT_START-$IP6BLOCK$IP6SNAT_END"
# install iptables-persistent (noninteractive since it asks questions during install) to make iptables rules persistent
DEBIAN_FRONTEND=noninteractive apt-get install iptables-persistent -y
# and then save the current rules
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
if [ "$SWITCHED_NETWORK" -eq 1 ]; then
	echo Setting up ndppd to respond to ipv6 neighbour solicitations for the whole network
	echo "proxy $INTERFACE {
    router no
    rule $IP6BLOCK::/$IP6BLOCK_SIZE {
        static
    }
}" > /etc/ndppd.conf
	apt-get install ndppd
fi
# setup done!
## Test things are working!
# docker run -it --rm --network ip6net debian:stable bash
# # in the container:
# # install curl
# > apt update && apt install curl
# # this should work & give you a random ip from the range:
# > curl https://ipv6.icanhazip.com
# # Note (see top of file) this ip will be sticky per source ip/container 
# #  (and if you exit this container and create another one, docker will likely give the same ip to the new one)
## Start AT containers:
# watchtower
docker run -d --name watchtower --restart=unless-stopped -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --label-enable --cleanup --interval 3600 --include-restarting

# start your project container
for i in {00..19}; do
  docker run -d --name archiveteam_$i --label=com.centurylinklabs.watchtower.enable=true --log-driver json-file --log-opt max-size=50m --restart=unless-stopped atdr.meo.ws/archiveteam/usgovernment-grab --concurrent 1 penguaman
  echo "archiveteam $i container started";
done
exit 0
