# Building a Layered OS Image

## Get the Base Image

The base image is the current cluster's RHCOS image. Always use the digest form:

```bash
BASE_IMAGE=$(oc adm release info --image-for rhel-coreos)
echo "$BASE_IMAGE"
# quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:...
```

## Containerfile

The Containerfile is simple -- replace the target binary and validate:

```dockerfile
FROM ${BASE_IMAGE}
COPY <binary> /usr/bin/<binary>
RUN chmod 755 /usr/bin/<binary> && bootc container lint
```

`bootc container lint` is required -- it validates the image is a valid bootable container. The build will warn about sysusers entries; warnings are OK, errors are not.

### Example: CRI-O

```dockerfile
FROM ${BASE_IMAGE}
COPY crio /usr/bin/crio
RUN chmod 755 /usr/bin/crio && bootc container lint
```

### Example: crun

```dockerfile
FROM ${BASE_IMAGE}
COPY crun /usr/bin/crun
RUN chmod 755 /usr/bin/crun && bootc container lint
```

### Example: kubelet

```dockerfile
FROM ${BASE_IMAGE}
COPY kubelet /usr/bin/kubelet
RUN chmod 755 /usr/bin/kubelet && bootc container lint
```

### Example: Multiple Binaries

```dockerfile
FROM ${BASE_IMAGE}
COPY crio /usr/bin/crio
COPY pinns /usr/bin/pinns
RUN chmod 755 /usr/bin/crio /usr/bin/pinns && bootc container lint
```

## Building

### Option A: Build on a Worker Node (Recommended)

Building on a worker node avoids QEMU emulation and is significantly faster. The binary must already be on the worker (from SCP during bind-mount testing).

```bash
# Create Containerfile on the worker
ssh core@${WORKER} "cat > /home/core/Containerfile <<EOF
FROM ${BASE_IMAGE}
COPY <binary> /usr/bin/<binary>
RUN chmod 755 /usr/bin/<binary> && bootc container lint
EOF"

# Build using the node's pull secrets
ssh core@${WORKER} "sudo podman build \
  --authfile /var/lib/kubelet/config.json \
  -t <image-name>:latest \
  -f /home/core/Containerfile /home/core/"
```

The `--authfile /var/lib/kubelet/config.json` gives podman access to pull the base RHCOS image from the cluster's registry.

### Option B: Build Locally with Docker

```bash
docker build --platform linux/amd64 \
  -f Containerfile -t <image-name>:latest .
```

You need the cluster pull secret in `~/.docker/config.json` to pull the base image.

## Pushing to a Registry

### Using the OpenShift Internal Registry

The internal registry is the simplest option -- no external registry needed.

**Expose the registry route** (if not already exposed):

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --patch '{"spec":{"defaultRoute":true}}' --type=merge

REGISTRY_ROUTE=$(oc get route -n openshift-image-registry default-route \
  -o jsonpath='{.spec.host}')
```

**Critical: Push to the `openshift-machine-config-operator` namespace.** The MCD uses `/etc/mco/internal-registry-pull-secret.json` to pull images. This secret only has access to `openshift-*` namespaces. If you push to a custom namespace, the MCD will fail with `authentication required`.

```bash
# Create a service account with push permissions IN the MCO namespace
oc create sa image-pusher -n openshift-machine-config-operator
oc policy add-role-to-user registry-editor \
  -z image-pusher -n openshift-machine-config-operator

# Get a push token
PUSH_TOKEN=$(oc create token image-pusher \
  -n openshift-machine-config-operator --duration=1h)

# Login and push (from the worker node)
ssh core@${WORKER} "sudo podman login --tls-verify=false \
  -u image-pusher -p '${PUSH_TOKEN}' ${REGISTRY_ROUTE}"

ssh core@${WORKER} "sudo podman tag localhost/<image-name>:latest \
  ${REGISTRY_ROUTE}/openshift-machine-config-operator/<image-name>:latest"

ssh core@${WORKER} "sudo podman push --tls-verify=false \
  ${REGISTRY_ROUTE}/openshift-machine-config-operator/<image-name>:latest"
```

**Get the digested image reference** (required for MachineConfig):

```bash
oc get istag -n openshift-machine-config-operator <image-name>:latest \
  -o jsonpath='{.image.dockerImageReference}'
# image-registry.openshift-image-registry.svc:5000/openshift-machine-config-operator/<image-name>@sha256:...
```

### Using an External Registry (quay.io, etc.)

Push to any registry the cluster can pull from. The cluster's global pull secret must include credentials for that registry.

```bash
podman push <image-name>:latest quay.io/<org>/<image-name>:latest
```

Get the digest:

```bash
podman inspect --format='{{.Digest}}' quay.io/<org>/<image-name>:latest
```

## Troubleshooting

### bootc container lint fails

Common issues:
- Missing `/usr/lib/os-release`
- Broken symlinks in `/usr`
- Package conflicts with base image RPMs

### Cannot pull base image

Ensure you have the cluster pull secret configured:
- On-node: `--authfile /var/lib/kubelet/config.json`
- Locally: cluster pull secret merged into `~/.docker/config.json`

### MCD fails with "authentication required"

The image was pushed to a namespace the MCD cannot pull from. Push to `openshift-machine-config-operator` namespace. See the push procedure above.
