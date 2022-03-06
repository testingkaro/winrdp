#!/bin/bash
FROM ubuntu:18.04
RUN apt-get update -y
RUN apt-get install -y qemu-kvm libvirt-daemon-system libvirt-dev
RUN apt-get install -y linux-image-$(uname -r)
RUN apt-get install -y curl net-tools jq
RUN apt-get autoclean
RUN apt-get autoremove
RUN curl -O https://releases.hashicorp.com/vagrant/$(curl -s https://checkpoint-api.hashicorp.com/v1/check/vagrant  | jq -r -M '.current_version')/vagrant_$(curl -s https://checkpoint-api.hashicorp.com/v1/check/vagrant  | jq -r -M '.current_version')_x86_64.deb
RUN dpkg -i vagrant_$(curl -s https://checkpoint-api.hashicorp.com/v1/check/vagrant  | jq -r -M '.current_version')_x86_64.deb
RUN vagrant plugin install vagrant-libvirt
RUN vagrant box add --provider libvirt peru/windows-10-enterprise-x64-eval
RUN vagrant init peru/windows-10-enterprise-x64-eval
COPY winrdp.sh /
ENTRYPOINT ["/winrdp.sh"]
#!/bin/bash
set -eou pipefail

chown root:kvm /dev/kvm
service libvirtd start
service virtlogd start
VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up
iptables-save > $HOME/firewall.txt
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -A FORWARD -i eth0 -o virbr1 -p tcp --syn --dport 3389 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth0 -o virbr1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i virbr1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 3389 -j DNAT --to-destination 192.168.121.68
iptables -t nat -A POSTROUTING -o virbr1 -p tcp --dport 3389 -d 192.168.121.68 -j SNAT --to-source 192.168.121.1

iptables -D FORWARD -o virbr1 -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -i virbr1 -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable

exec "$@"
