# Release Note Templates

Copy-paste templates for each release note type. Replace placeholders in angle brackets.

## New Feature Template

```asciidoc
* You can now <description of the new capability>. <One sentence on the benefit or use case>. For more information, see xref:<path/to/assembly.adoc>#<anchor>[<Link text>]. (link:https://issues.redhat.com/browse/<JIRA-ID>[<JIRA-ID>])
```

### Node team example -- new feature

```asciidoc
* You can now configure the kubelet to use swap memory on worker nodes by setting the `swapBehavior` field in the `KubeletConfig` custom resource to `LimitedSwap`. This enables workloads that benefit from swap to handle memory pressure more gracefully without being OOM-killed. For more information, see xref:nodes/nodes/nodes-nodes-swap-memory.adoc#nodes-nodes-swap-memory[Swap memory on nodes]. (link:https://issues.redhat.com/browse/OCPSTRAT-890[OCPSTRAT-890])
```

### Node team example -- MCO feature

```asciidoc
* You can now define node disruption policies in a `MachineConfiguration` object to specify which `MachineConfig` changes should not trigger a node reboot. This reduces unnecessary downtime during routine configuration updates such as certificate rotations or SSH key changes. For more information, see xref:machine_configuration/machine-config-node-disruption.adoc#machine-config-node-disruption[Node disruption policies]. (link:https://issues.redhat.com/browse/MCO-334[MCO-334])
```

## Bug Fix Template

```asciidoc
* Previously, <description of the old, incorrect behavior and its impact>. With this update, <description of the corrected behavior>. (link:https://issues.redhat.com/browse/<JIRA-ID>[<JIRA-ID>])
```

### Node team example -- kubelet bug fix

```asciidoc
* Previously, when a node had the topology manager policy set to `single-numa-node` and a pod requested both CPU and hugepages resources, the topology manager would fail to align the resources to the same NUMA node, causing the pod to remain in a `Pending` state. With this update, the topology manager correctly considers hugepages resources during NUMA alignment. (link:https://issues.redhat.com/browse/OCPBUGS-22334[OCPBUGS-22334])
```

### Node team example -- MCO bug fix

```asciidoc
* Previously, when a `MachineConfigPool` had both paused and unpaused nodes, the Machine Config Operator would not resume draining nodes correctly after the pool was unpaused, leaving nodes in a degraded state. With this update, the Machine Config Operator correctly reconciles the drain state for all nodes in the pool when the pool is unpaused. (link:https://issues.redhat.com/browse/OCPBUGS-15678[OCPBUGS-15678])
```

### Node team example -- CRI-O bug fix

```asciidoc
* Previously, when CRI-O received a `StopContainer` request while a container was still being created, a race condition could cause the container to remain in an unknown state on the node. With this update, CRI-O correctly serializes create and stop operations, ensuring the container is cleanly removed. (link:https://issues.redhat.com/browse/OCPBUGS-44556[OCPBUGS-44556])
```

## Known Issue Template

```asciidoc
* When <condition or scenario>, <description of the problem and its impact>. As a workaround, <mitigation steps>. (link:https://issues.redhat.com/browse/<JIRA-ID>[<JIRA-ID>])
```

### Node team example -- known issue

```asciidoc
* When a node is configured to use cgroups v2 and the `cpuManagerPolicy` is set to `static`, the CPU manager might not correctly restore CPU assignments after a kubelet restart, causing guaranteed pods to lose their exclusive CPU allocation. As a workaround, drain the node and delete the `cpu_manager_state` file at `/var/lib/kubelet/cpu_manager_state` before restarting the kubelet. (link:https://issues.redhat.com/browse/OCPBUGS-33445[OCPBUGS-33445])
```

### Node team example -- MCO known issue

```asciidoc
* When you apply a `MachineConfig` that modifies kernel arguments and another `MachineConfig` that changes the container runtime configuration simultaneously, the Machine Config Operator might process only one of the changes, requiring a second reboot to apply the other. As a workaround, apply the `MachineConfig` changes sequentially and wait for the `MachineConfigPool` to finish updating before applying the next change. (link:https://issues.redhat.com/browse/OCPBUGS-78901[OCPBUGS-78901])
```

## Deprecation Notice Template

```asciidoc
* <Feature or API field> is deprecated. In a future release, <what will happen -- removal, replacement>. Use <alternative> instead. For more information, see xref:<path/to/assembly.adoc>#<anchor>[<Link text>].
```

### Node team example -- deprecation

```asciidoc
* The `cpuManagerReconcilePeriod` field in the `KubeletConfig` custom resource is deprecated. In a future release, this field will be removed and the CPU manager will use a fixed reconciliation interval. No action is required; the default behavior is unchanged.
```

### Node team example -- API deprecation

```asciidoc
* The `v1alpha1` version of the `NodeDisruptionPolicy` API is deprecated. In a future release, this version will be removed. Migrate your `NodeDisruptionPolicy` objects to use the `v1` API version instead. For more information, see xref:machine_configuration/machine-config-node-disruption.adoc#machine-config-node-disruption[Node disruption policies].
```

## Technology Preview Template

```asciidoc
* <Feature name> is now available as a Technology Preview feature. <One sentence description of what it does>. For more information, see xref:<path/to/assembly.adoc>#<anchor>[<Link text>]. (link:https://issues.redhat.com/browse/<JIRA-ID>[<JIRA-ID>])
```

### Node team example -- tech preview

```asciidoc
* Swap memory support on worker nodes is now available as a Technology Preview feature. You can enable swap on nodes and configure the kubelet to use `LimitedSwap` behavior, allowing burstable QoS pods to use swap when the node is under memory pressure. For more information, see xref:nodes/nodes/nodes-nodes-swap-memory.adoc#nodes-nodes-swap-memory[Swap memory on nodes]. (link:https://issues.redhat.com/browse/OCPSTRAT-890[OCPSTRAT-890])
```

### Node team example -- MCO tech preview

```asciidoc
* On-cluster layering with the Machine Config Operator is now available as a Technology Preview feature. You can build custom layered images using a `MachineOSConfig` object, allowing you to add RPMs and configuration to the base {product-title} image without maintaining a separate image build pipeline. For more information, see xref:machine_configuration/machine-config-on-cluster-layering.adoc#machine-config-on-cluster-layering[On-cluster layering]. (link:https://issues.redhat.com/browse/MCO-589[MCO-589])
```

## Checklist Before Submitting

- [ ] Entry follows the correct template pattern for its type
- [ ] Jira link is included and the issue key is correct
- [ ] Entry uses `{product-title}` instead of hardcoded product name
- [ ] API fields and CLI commands are in monospace
- [ ] Feature entries include an `xref:` to the docs page
- [ ] Entry is 2-3 sentences maximum
- [ ] "Previously" is used to start bug fix entries
- [ ] "As a workaround" is used for known issue mitigations
- [ ] Component names are spelled out on first reference
