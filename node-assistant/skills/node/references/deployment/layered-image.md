# Deploying via RHCOS Layered Image

For cluster-wide deployment that survives reboots, use RHCOS image layering instead of bind mounts. This creates a custom OS image with your binary baked in, and the MCO (Machine Config Operator) rolls it out to all nodes in a machine config pool.

## When to Use

| Approach | Use Case |
|----------|----------|
| **Bind mount** | Quick single-node testing, rapid iteration |
| **Layered image** | Need the binary on ALL nodes, need it to survive reboots, simulating customer deployment |

Layered images are how customers would deploy a custom binary in production -- the binary goes in the image, and a MachineConfig drops the configuration that enables the feature.

## Concept

1. Get the base RHCOS image digest from the cluster
2. Build a layered image that replaces the target binary
3. Push to a registry the cluster can pull from
4. Apply a `MachineConfig` with `osImageURL` pointing to the layered image
5. MCO drains and reboots each node with the new image

## Sub-References

- **Building the image**: [layered-image/building.md](layered-image/building.md) -- Containerfile examples, building on-node vs locally, pushing to registries
- **MCO rollout**: [layered-image/mco-rollout.md](layered-image/mco-rollout.md) -- Applying MachineConfig, monitoring rollout, pause/resume, rollback

## Quick Start

```bash
# 1. Get the base RHCOS image
BASE_IMAGE=$(oc adm release info --image-for rhel-coreos)

# 2. Build a layered image (on a worker node with the binary at /home/core/crio)
ssh core@${WORKER} "cat > /home/core/Containerfile <<EOF
FROM ${BASE_IMAGE}
COPY crio /usr/bin/crio
RUN chmod 755 /usr/bin/crio && bootc container lint
EOF"

ssh core@${WORKER} "sudo podman build \
  --authfile /var/lib/kubelet/config.json \
  -t crio-custom:latest \
  -f /home/core/Containerfile /home/core/"

# 3. Push to internal registry (MCO namespace)
# See layered-image/building.md for full push procedure

# 4. Apply MachineConfig with osImageURL
# See layered-image/mco-rollout.md for the MachineConfig YAML

# 5. Monitor: oc get mcp worker -w
```

## Safety Considerations

- Layered image rollout **reboots every node** in the pool (one at a time). This takes 30-60 minutes for a 3-worker cluster.
- Always validate the binary via bind-mount on a single node FIRST, then build the layered image.
- The `bootc container lint` step is required -- it validates the image is a valid bootable container.
- Push to the `openshift-machine-config-operator` namespace in the internal registry. The MCD only has pull access to `openshift-*` namespaces.
- Rollback is deleting the MachineConfig, which triggers another full rollout back to the stock image.

## Adding Configuration

After the layered image is rolled out, drop configuration files via a separate MachineConfig. This is how customers enable features -- the binary is deployed first, then the config turns it on. See [layered-image/mco-rollout.md](layered-image/mco-rollout.md) for details.
