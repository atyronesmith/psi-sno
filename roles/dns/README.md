# Openstack VM for CoreDNS

## Steps

Start with a Fedora cloud image

```bash
wget https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2

openstack image create --disk-format qcow2 --container-format bare --progress --file ./Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 nfv-dns

openstack server create --flavor  --image Fedora-Cloud-Base-42-latest \
     --network sno-nfv
```

Create an instance with:
- 4G Ram
- 10 G Disk
- 2 vCPU

Assign a floating ip.

Run the `setup.yml` playbook.

```bash
ansible-playbook -v setup.yml -i 10.0.111.215,
```

The playboard will:
- Add the coredns user
- Download and install `coredns`
- Create a basic config file (/etc/coredns/Corefile) for `coredns`
- Create a *systemd* service for `coredns`
- Start the service

Create security group for DNS

```bash
openstack security group create --description "CoreDNS Server for PSI" "coredns-psi"

echo "Adding rules to security group $name..."
openstack security group rule create --remote-ip 0.0.0.0/0 --protocol tcp --dst-port 22 "coredns-psi"
openstack security group rule create --remote-ip 0.0.0.0/0 --protocol tcp --dst-port 53 "coredns-psi"
openstack security group rule create --remote-ip 0.0.0.0/0 --protocol udp --dst-port 53 "coredns-psi"

openstack server add security group nfv-fedora coredns-psi
```

## Adding clusters to DNS
The list of cluster names, domains, and ips are set in the `./clusters.yml` file.
Edit that file with cluster information.

Run the playboook `add_cluster.yml` to configure the DNS cluster information for all clusters.
```bash
ansible-playbook -v add_cluster.yml -i 10.0.111.215,
```

ntp server is clock.corp.redhat.com

## --- OLD ---
## Add User
useradd -d /var/lib/coredns coredns

## Install coredns
```bash

sudo dnf install -y wget

wget https://github.com/coredns/coredns/releases/download/v1.12.1/coredns_1.12.1_linux_amd64.tgz

tar xvf coredns_1.12.1_linux_amd64.tgz

sudo mv coredns /usr/bin

sudo useradd -d /var/lib/coredns coredns

sudo chown coredns:coredns /usr/bin/coredns

sudo restorecon -rv /usr/bin/coredns

sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/coredns
```

## Systemd
Use `coredns.service` as a systemd service file. It defaults to using a "coredns" user with a homedir of /var/lib/coredns and the binary lives in /usr/bin and the config in /etc/coredns/Corefile.

- Put Corefile at /etc/coredns/Corefile
- Put nfv.com at /etc/coredns/nfv.com
- Put coredns-sysusers.conf in /usr/lib/sysusers.d
- Put coredns-tmpfiles.conf in /usr/lib/tmpfiles.d
- Put coredns-log.conf in /etc/logrotate.d

## Make a cloud image
https://docs.openstack.org/image-guide/create-images-manually-example-fedora-image.html

# Dns Servers
# 10.11.5.160 10.2.70.215