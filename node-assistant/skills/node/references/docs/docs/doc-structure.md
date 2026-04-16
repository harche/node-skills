# OpenShift Docs Directory Structure

## Modules vs Assemblies

The `openshift-docs` repo uses a **modular documentation** architecture:

- **Modules** live in `modules/<topic>/` and contain a single unit of content (one concept, one procedure, or one reference).
- **Assemblies** live in topic directories (e.g., `nodes/nodes/`) and pull modules together into a published page using `include::` directives.
- **Topic maps** in `_topic_maps/` define the navigation tree and map assemblies to URLs.

A module is never published directly. It is always included in at least one assembly.

## Naming Conventions

### Module prefixes

| Prefix | Type | Example |
|--------|------|---------|
| `con_` | Concept | `con_nodes-nodes-about.adoc` |
| `proc_` | Procedure | `proc_nodes-nodes-viewing.adoc` |
| `ref_` | Reference | `ref_nodes-nodes-resources.adoc` |

### Naming pattern

```
<prefix>_<topic-area>-<specific-topic>.adoc
```

Examples:
- `proc_nodes-nodes-managing-max-pods.adoc`
- `con_nodes-cgroups-about.adoc`
- `ref_nodes-kubelet-config-parameters.adoc`

### Assembly naming

Assemblies do not use a prefix. They follow the pattern:

```
<topic-area>-<specific-topic>.adoc
```

Examples:
- `nodes-nodes-working.adoc`
- `nodes-nodes-managing-max-pods.adoc`
- `nodes-cluster-overcommit.adoc`

## Directory Layout

```
openshift-docs/
  _topic_maps/
    _topic_map.yml              # Main navigation structure
  _distro_map.yml               # Distro-to-branch mapping
  _attributes/
    common-attributes.adoc      # Shared AsciiDoc attributes ({product-title}, etc.)
  modules/
    nodes/                      # Node-related modules
    machine_config/             # MCO modules
    monitoring/                 # Monitoring modules
    ...
  nodes/
    nodes/                      # Node management assemblies
    scheduling/                 # Scheduler assemblies
    pods/                       # Pod assemblies
    containers/                 # Container assemblies
    jobs/                       # Job assemblies
    clusters/                   # Cluster-level node config assemblies
  machine_configuration/        # MachineConfig assemblies
  monitoring/                   # Monitoring assemblies
  scalability_and_performance/  # Performance tuning assemblies
  rest_api/
    node_apis/                  # Node API reference
  images/                       # All images/screenshots
  snippets/                     # Reusable text fragments
```

## Node-Relevant Directories and Files

### `modules/nodes/`

Core Node team modules:

```
modules/nodes/
  con_nodes-nodes-about.adoc
  proc_nodes-nodes-viewing.adoc
  proc_nodes-nodes-working-updating.adoc
  con_nodes-nodes-garbage-collection.adoc
  proc_nodes-nodes-managing-max-pods.adoc
  con_nodes-cgroups-about.adoc
  proc_nodes-cgroups-configuring.adoc
  ref_nodes-kubelet-config-parameters.adoc
  con_nodes-containers-downward-api.adoc
  proc_nodes-nodes-swap-memory.adoc
  con_nodes-graceful-shutdown.adoc
  proc_nodes-nodes-kernel-arguments.adoc
  ref_nodes-node-disruption-policies.adoc
  ...
```

### `modules/machine_config/`

MCO-related modules:

```
modules/machine_config/
  con_machine-config-operator.adoc
  proc_machineconfig-creating.adoc
  proc_machineconfig-modify-journald.adoc
  ref_machineconfig-garbage-collection.adoc
  con_machine-config-drift-detection.adoc
  ...
```

### Node assemblies in `nodes/`

```
nodes/
  nodes/
    nodes-nodes-working.adoc
    nodes-nodes-managing-max-pods.adoc
    nodes-nodes-garbage-collection.adoc
    nodes-nodes-resources-configuring.adoc
    nodes-nodes-kernel-arguments.adoc
    nodes-cluster-overcommit.adoc
  clusters/
    nodes-cluster-cgroups-2.adoc
    nodes-cluster-enabling-features.adoc
```

## Topic Map Structure

The `_topic_maps/_topic_map.yml` file defines the navigation. Node entries look like:

```yaml
---
Name: Nodes
Dir: nodes
Distros: openshift-enterprise,openshift-origin
Topics:
  - Name: Nodes
    Dir: nodes
    Topics:
      - Name: Working with nodes
        File: nodes-nodes-working
      - Name: Managing max pods per node
        File: nodes-nodes-managing-max-pods
      - Name: Node garbage collection
        File: nodes-nodes-garbage-collection
  - Name: Scheduling
    Dir: scheduling
    Topics:
      - Name: Controlling pod placement
        File: nodes-scheduler-about
```

## How to Add a New Page

1. **Create the module(s)** in `modules/nodes/` (or appropriate subdirectory):
   ```
   modules/nodes/con_nodes-my-new-feature.adoc
   modules/nodes/proc_nodes-my-new-feature-configuring.adoc
   modules/nodes/ref_nodes-my-new-feature-parameters.adoc
   ```

2. **Set the module header** with content type and assembly reference:
   ```asciidoc
   // Module included in the following assemblies:
   //
   // * nodes/nodes/nodes-my-new-feature.adoc

   :_mod-docs-content-type: CONCEPT

   [id="nodes-my-new-feature-about_{context}"]
   = About my new feature
   ```

3. **Create the assembly** in the topic directory (e.g., `nodes/nodes/`):
   ```asciidoc
   :_mod-docs-content-type: ASSEMBLY
   [id="nodes-my-new-feature"]
   = My new feature
   :context: nodes-my-new-feature

   include::_attributes/common-attributes.adoc[]

   include::modules/nodes/con_nodes-my-new-feature.adoc[leveloffset=+1]
   include::modules/nodes/proc_nodes-my-new-feature-configuring.adoc[leveloffset=+1]
   include::modules/nodes/ref_nodes-my-new-feature-parameters.adoc[leveloffset=+1]
   ```

4. **Add the assembly to the topic map** in `_topic_maps/_topic_map.yml`:
   ```yaml
   - Name: My new feature
     File: nodes-my-new-feature
   ```
   Place it under the appropriate `Dir` and `Topics` section.

5. **Build and verify** locally using `asciibinder build --distro openshift-enterprise`.

6. **Open a PR** against the appropriate branch.

## How to Update Existing Content

1. **Find the assembly** for the page you want to update. Start from the published URL and map it back through the topic map, or search for key terms in the repo.

2. **Find the module** included by the assembly. Open the assembly and look at the `include::` directives.

3. **Edit the module** directly. Do not edit the assembly unless you are adding or removing modules.

4. **Check for reuse.** Look at the module's header comment to see if it is included in multiple assemblies. Your change will affect all of them.

5. **Check for conditionals.** If the content differs by distro, make sure your changes respect existing `ifdef`/`endif` blocks.

6. **Update the module header comment** if you include the module in a new assembly.

7. **Build locally** to verify rendering, especially for tables, code blocks, and admonitions.

## Common Pitfalls

- **Module without an assembly** -- Modules that are not included in any assembly are orphans and never published. Always update the assembly.
- **Topic map mismatch** -- If the topic map file name does not match the assembly file name (without `.adoc`), the page will not build.
- **Duplicate anchors** -- If a module is included in multiple assemblies, all anchors must use `{context}` to avoid collisions.
- **Missing `common-attributes.adoc` include** -- Assemblies that skip this include will have unresolved `{product-title}` attributes.
