#!/bin/bash
#********************************************************************
#Author:		bravewang
#QQ: 			6142553
#blog:			http://brave666.blog.51cto.com/
#Date: 			2017-11-14
#********************************************************************
export host1=192.168.2.11
export host2=192.168.2.12
export host3=192.168.2.13
export zhuji="$host1 $host2 $host3"

cat << EOF > etcd-csr.json 
{
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "etcd",
      "OU": "etcd Security",
      "L": "Beijing",
      "ST": "Beijing",
      "C": "CN"
    }
  ],
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "localhost",
    "$host1",
    "$host2",
    "$host3",
    "$host4",
    "$host5"
  ]
}
EOF

cat << EOF > etcd-gencert.json
{
  "signing": {
    "default": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "87600h"
    }
  }
}
EOF

cat << EOF > etcd-root-ca-csr.json
{
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "O": "etcd",
      "OU": "etcd Security",
      "L": "Beijing",
      "ST": "Beijing",
      "C": "CN"
    }
  ],
  "CN": "etcd-root-ca"
}
EOF

cfssl gencert --initca=true etcd-root-ca-csr.json | cfssljson --bare etcd-root-ca
cfssl gencert --ca etcd-root-ca.pem --ca-key etcd-root-ca-key.pem --config etcd-gencert.json etcd-csr.json | cfssljson --bare etcd

#for IP in $zhuji ; do
#   scp etcd-3.2.7-1.fc28.x86_64.rpm root@$IP:~
#   ssh root@$IP rpm -ivh etcd-3.2.7-1.fc28.x86_64.rpm
#done
for IP in $zhuji ;do
    ssh root@$IP mkdir /etc/etcd/ssl
    scp *.pem root@$IP:/etc/etcd/ssl
    ssh root@$IP chown -R etcd:etcd /etc/etcd/ssl
    ssh root@$IP chmod -R 644 /etc/etcd/ssl/*
    ssh root@$IP chmod 755 /etc/etcd/ssl
    ssh root@$IP chown -R etcd:etcd /var/lib/etcd
done

conf()
{
cat << EOF > etcd${IP##*.}.conf
# [member]
ETCD_NAME=etcd${IP: -1}
ETCD_DATA_DIR="/var/lib/etcd/etcd.etcd"
ETCD_WAL_DIR="/var/lib/etcd/wal"
ETCD_SNAPSHOT_COUNT="100"
ETCD_HEARTBEAT_INTERVAL="100"
ETCD_ELECTION_TIMEOUT="1000"
ETCD_LISTEN_PEER_URLS="https://$IP:2380"
ETCD_LISTEN_CLIENT_URLS="https://$IP:2379,http://127.0.0.1:2379"
ETCD_MAX_SNAPSHOTS="5"
ETCD_MAX_WALS="5"
#ETCD_CORS=""

# [cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$IP:2380"
# if you use different ETCD_NAME (e.g. test), set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="etcd1=https://$host1:2380,etcd2=https://$host2:2380,etcd3=https://$host3:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://$IP:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_SRV=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
#ETCD_STRICT_RECONFIG_CHECK="false"
#ETCD_AUTO_COMPACTION_RETENTION="0"

# [proxy]
#ETCD_PROXY="off"
#ETCD_PROXY_FAILURE_WAIT="5000"
#ETCD_PROXY_REFRESH_INTERVAL="30000"
#ETCD_PROXY_DIAL_TIMEOUT="1000"
#ETCD_PROXY_WRITE_TIMEOUT="5000"
#ETCD_PROXY_READ_TIMEOUT="0"

# [security]
ETCD_CERT_FILE="/etc/etcd/ssl/etcd.pem"
ETCD_KEY_FILE="/etc/etcd/ssl/etcd-key.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ssl/etcd-root-ca.pem"
ETCD_AUTO_TLS="true"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/etcd-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ssl/etcd-root-ca.pem"
ETCD_PEER_AUTO_TLS="true"

# [logging]
#ETCD_DEBUG="false"
# examples for -log-package-levels etcdserver=WARNING,security=DEBUG
#ETCD_LOG_PACKAGE_LEVELS=""
EOF
}

for IP in $zhuji; do
    ssh root@$IP hostnamectl set-hostname docker${IP##*.}
    conf
    scp etcd${IP##*.}.conf root@$IP:/etc/etcd/etcd.conf
    ssh root@$IP systemctl daemon-reload
    sleep 1
    ssh root@$IP systemctl restart etcd
    sleep 2
    ssh root@$IP systemctl enable etcd
done
