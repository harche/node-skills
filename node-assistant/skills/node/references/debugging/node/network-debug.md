# Node Network Debugging

Network debugging for OpenShift nodes covering pod connectivity, DNS, CNI plugins, and namespace inspection.

## Getting a Debug Shell

```bash
oc debug node/<node>
chroot /host
```

## Pod-to-Pod Connectivity

### From the Cluster Side

```bash
# Test pod-to-pod with a debug pod
oc run nettest --image=registry.access.redhat.com/ubi9/ubi-minimal --rm -it --restart=Never -- curl -s <target-pod-ip>:<port>

# Check pod IPs and node placement
oc get pods -o wide -A | grep <pod-name>

# Check endpoints for a service
oc get endpoints <service> -n <namespace>
```

### From the Node

```bash
# Ping a pod IP from the node
ping -c 3 <pod-ip>

# Curl a pod directly
curl -s --connect-timeout 5 http://<pod-ip>:<port>

# Check routing to pod network
ip route | grep <pod-subnet>
```

## Service DNS Resolution

```bash
# From a pod
oc run dnstest --image=registry.access.redhat.com/ubi9/ubi-minimal --rm -it --restart=Never -- nslookup <service>.<namespace>.svc.cluster.local

# Check CoreDNS pods
oc get pods -n openshift-dns -o wide

# Check DNS service
oc get svc -n openshift-dns

# Check resolv.conf inside a pod
oc exec <pod> -- cat /etc/resolv.conf

# From the node (host DNS, not cluster DNS)
cat /etc/resolv.conf
nslookup <hostname>
```

## CNI Plugin Debugging

### OVN-Kubernetes (Default in OpenShift 4.x)

```bash
# Check OVN-Kubernetes pods
oc get pods -n openshift-ovn-kubernetes -o wide

# Check ovnkube-node on this specific node
oc logs -n openshift-ovn-kubernetes <ovnkube-node-pod> -c ovnkube-controller
oc logs -n openshift-ovn-kubernetes <ovnkube-node-pod> -c ovn-controller

# OVS bridges
ovs-vsctl show

# OVS flows (on node)
ovs-ofctl dump-flows br-int | head -50

# OVN southbound database (from node)
ovn-sbctl show
ovn-sbctl list port_binding | grep -A 5 <pod-name>

# OVN northbound (from ovnkube-master pod)
ovn-nbctl show
ovn-nbctl list logical_switch_port | grep -A 5 <pod-name>

# Check OVN-K node annotations
oc get node <node> -o jsonpath='{.metadata.annotations}' | python3 -m json.tool | grep ovn
```

### OpenShift SDN (Legacy)

```bash
# Check SDN pods
oc get pods -n openshift-sdn -o wide

# Check SDN node logs
oc logs -n openshift-sdn <sdn-pod>

# VNID mapping
oc get netnamespace

# Check OVS flows
ovs-ofctl dump-flows br0 | head -50
```

### CNI Configuration

```bash
# CNI config directory
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conflist

# CNI binary directory
ls /opt/cni/bin/

# CNI logs in CRI-O
journalctl -u crio --no-pager | grep -i cni
```

## Node Port Connectivity

```bash
# Check NodePort services
oc get svc -A --field-selector spec.type=NodePort

# Check if port is listening on node
ss -tlnp | grep <port>

# Test NodePort from outside
curl -s --connect-timeout 5 http://<node-ip>:<node-port>
```

## iptables / nftables Rules

OpenShift 4.x with OVN-Kubernetes uses OVS flows rather than iptables for most traffic steering, but iptables/nftables rules still exist for some functions.

```bash
# List iptables rules (if using iptables mode)
iptables -L -n -v --line-numbers
iptables -t nat -L -n -v --line-numbers

# Check nftables (RHCOS 9+)
nft list ruleset

# Check which firewall backend
cat /etc/firewalld/firewalld.conf | grep FirewallBackend

# kube-proxy rules (if applicable)
iptables -t nat -L KUBE-SERVICES -n | head -20
```

## Network Namespace Inspection

Each pod gets its own network namespace. To inspect a specific pod's network:

```bash
# Find the pod's network namespace
crictl pods --name <pod-name>
crictl inspectp <pod-id> | grep -i netns
# Output will include something like: /var/run/netns/xxxxxxxx

# Or find it from the PID
PID=$(crictl inspect <container-id> | grep '"pid"' | head -1 | awk '{print $2}' | tr -d ',')
ls -la /proc/$PID/ns/net
```

### nsenter for Network Namespace

```bash
# Enter the pod's network namespace from the node
nsenter -t $PID -n ip addr
nsenter -t $PID -n ip route
nsenter -t $PID -n ss -tlnp
nsenter -t $PID -n ping -c 3 <target>
nsenter -t $PID -n curl -s <url>

# DNS from the pod's perspective
nsenter -t $PID -n cat /etc/resolv.conf
nsenter -t $PID -n nslookup <service>.<namespace>.svc.cluster.local
```

### Using ip netns

```bash
# List network namespaces (only shows named ones in /var/run/netns)
ip netns list

# Execute command in a named namespace
ip netns exec <ns-name> ip addr
ip netns exec <ns-name> ip route
ip netns exec <ns-name> ss -tlnp
```

## Common Debugging Scenarios

### Pod Cannot Reach Another Pod

1. Check both pods are running and have IPs:
   ```bash
   oc get pods -o wide
   ```
2. Check they are on the same or different nodes
3. If same node: check OVS bridge flows, local routing
4. If different nodes: check inter-node tunnel (Geneve for OVN-K)
   ```bash
   ovs-vsctl show | grep -A 3 genev
   ip route | grep <remote-pod-subnet>
   ```
5. Check NetworkPolicy:
   ```bash
   oc get networkpolicy -n <namespace>
   ```

### DNS Not Resolving

1. Check CoreDNS pods are healthy:
   ```bash
   oc get pods -n openshift-dns
   ```
2. Check DNS service has endpoints:
   ```bash
   oc get endpoints -n openshift-dns dns-default
   ```
3. Test from the pod's namespace:
   ```bash
   nsenter -t $PID -n nslookup kubernetes.default.svc.cluster.local <dns-service-ip>
   ```
4. Check `/etc/resolv.conf` inside pod is correct

### Node Network Interface Issues

```bash
# Interface status
ip link show
ip addr show

# Check for errors/drops
ip -s link show <interface>

# NetworkManager connections
nmcli connection show
nmcli device status

# Check bonding/teaming (if used)
cat /proc/net/bonding/bond0  # if bonded

# ethtool stats
ethtool -S <interface> | grep -i err
```

### Packet Capture

```bash
# Capture on node interface
tcpdump -i <interface> -nn -c 100 host <ip>

# Capture on OVS internal port
tcpdump -i genev_sys_6081 -nn -c 50

# Capture in pod's network namespace
nsenter -t $PID -n tcpdump -i eth0 -nn -c 100

# Write to file for analysis
tcpdump -i <interface> -nn -w /tmp/capture.pcap -c 1000 host <ip>
```
