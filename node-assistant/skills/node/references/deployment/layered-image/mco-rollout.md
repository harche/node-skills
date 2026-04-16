# Rolling Out a Layered Image via MCO

## Apply the MachineConfig

Create a MachineConfig with `osImageURL` pointing to the layered image:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-custom-os-image
spec:
  osImageURL: image-registry.openshift-image-registry.svc:5000/openshift-machine-config-operator/<image-name>@sha256:<digest>
```

Apply it:

```bash
oc apply -f machineconfig-layered.yaml
```

## What Happens

The MCO will:
1. Render a new machine config combining all MachineConfigs for the pool
2. Cordon and drain each node (one at a time)
3. Run `rpm-ostree rebase` to the new image
4. Reboot the node
5. Uncordon when healthy

## Monitor Rollout

```bash
# Watch the machine config pool
oc get mcp worker -w
# UPDATED=False, UPDATING=True while rolling out
# UPDATED=True, UPDATING=False when complete

# Watch node status
oc get nodes -w
# SchedulingDisabled = node being updated
# NotReady = node rebooting
```

## Pause and Resume Rollout

To pause mid-rollout (e.g., to check the first updated node before proceeding):

```bash
# Pause
oc patch mcp worker --type merge --patch '{"spec":{"paused":true}}'

# Check the updated node
oc get nodes
ssh core@${UPDATED_NODE} "sudo crio --version"

# Resume
oc patch mcp worker --type merge --patch '{"spec":{"paused":false}}'
```

## Adding Configuration via MachineConfig

After the layered image is rolled out, drop configuration files via a separate MachineConfig. This is how customers enable features -- the binary is deployed first, then the config turns it on.

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-feature-config
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,<base64-encoded-config>
        mode: 0644
        overwrite: true
        path: <config-drop-in-path>
```

Generate base64 content:

```bash
echo -n '[crio.runtime]
default_runtime = "crun"
' | base64
```

This triggers another MCO rollout (drain + reboot per node).

## Rollback

Delete the MachineConfig to revert all nodes to the base RHCOS image:

```bash
oc delete mc 99-worker-custom-os-image
```

The MCO will drain and reboot each node back to the stock OS image. This takes the same amount of time as the original rollout.

To also remove the configuration:

```bash
oc delete mc 99-worker-feature-config
```

## Troubleshooting

### MCP stuck in Degraded

The MCD caches the old rendered config and keeps retrying the failed image URL.

1. Delete the old MachineConfig
2. Wait for a new rendered config: `oc get mc --sort-by=.metadata.creationTimestamp`
3. Apply the corrected MachineConfig
4. If MCD is still stuck, force-annotate the node:

```bash
# Get the desired rendered config
RENDERED=$(oc get mcp worker -o jsonpath='{.spec.configuration.name}')

oc annotate node <node> \
  machineconfiguration.openshift.io/desiredConfig=${RENDERED} \
  --overwrite
```

5. If still stuck, restart the MCD pod on that node:

```bash
oc delete pod -n openshift-machine-config-operator \
  -l k8s-app=machine-config-daemon \
  --field-selector spec.nodeName=<node> --force --grace-period=0
```

### Node stays NotReady after reboot

Check kubelet and CRI-O status via SSH:

```bash
ssh core@${NODE} "sudo systemctl is-active crio kubelet"
ssh core@${NODE} "sudo journalctl -u crio --no-pager -n 20"
ssh core@${NODE} "sudo journalctl -u kubelet --no-pager -n 20"
```

### Rollout is too slow

The MCO updates one node at a time by default. To increase parallelism (at the cost of reduced cluster capacity during rollout):

```bash
oc patch mcp worker --type merge --patch '{"spec":{"maxUnavailable":2}}'
```

Reset to default after rollout:

```bash
oc patch mcp worker --type merge --patch '{"spec":{"maxUnavailable":1}}'
```
