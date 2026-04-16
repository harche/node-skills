# AsciiDoc Reference for OpenShift Docs

## Headings

```asciidoc
= Document Title (Level 0 -- only in assemblies)
== Section (Level 1)
=== Subsection (Level 2)
==== Sub-subsection (Level 3)
```

Modules typically start at `==` since the `=` title comes from the assembly. Use the `:_mod-docs-content-type:` attribute at the top of each module:

```asciidoc
// Module included in the following assemblies:
//
// * nodes/nodes/nodes-nodes-working.adoc

:_mod-docs-content-type: PROCEDURE
```

## Inline Formatting

```asciidoc
*bold text*
_italic text_
`monospace / code`
*`bold monospace`*
```

Use `monospace` for: CLI commands, file paths, API object names, field names, values, environment variables.

## Code Blocks

```asciidoc
[source,yaml]
----
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-custom-kubelet
----
```

For terminal output (no syntax highlighting):

```asciidoc
[source,terminal]
----
$ oc get nodes
----
```

For output that follows a command:

```asciidoc
.Example output
[source,terminal]
----
NAME           STATUS   ROLES    AGE   VERSION
worker-0       Ready    worker   10d   v1.28.0
----
```

Use `[source,terminal]` for commands the user runs. Use `[source,text]` for generic output without `$` prefix.

## Admonitions

```asciidoc
NOTE: Additional information the user should be aware of.

IMPORTANT: Critical information required for success.

WARNING: Actions that might cause data loss or downtime.

TIP: Optional but helpful suggestions.

CAUTION: Potential negative consequences of an action.
```

For multi-line admonitions:

```asciidoc
[NOTE]
====
This is a multi-line note.

It can contain multiple paragraphs and code blocks.
====
```

## Conditional Text

Use `ifdef`/`endif` to conditionally include content based on the distro:

```asciidoc
ifdef::openshift-enterprise[]
This content only appears in OCP docs.
endif::openshift-enterprise[]

ifdef::openshift-origin[]
This content only appears in OKD docs.
endif::openshift-origin[]

ifndef::openshift-dedicated[]
This content appears in all distros except OSD.
endif::openshift-dedicated[]
```

Multiple distros:

```asciidoc
ifdef::openshift-enterprise,openshift-origin[]
Content for both OCP and OKD.
endif::openshift-enterprise,openshift-origin[]
```

Common distro keys: `openshift-enterprise`, `openshift-origin`, `openshift-dedicated`, `openshift-rosa`.

## Include Directives

Assemblies include modules using the `include::` directive:

```asciidoc
include::modules/nodes-nodes-working-about.adoc[leveloffset=+1]
```

The `leveloffset=+1` bumps all headings in the included module down one level (so `==` in the module renders as `===` in the assembly).

Include with conditions:

```asciidoc
ifdef::openshift-enterprise[]
include::modules/nodes-nodes-ocp-specific.adoc[leveloffset=+1]
endif::openshift-enterprise[]
```

## Cross-References and Links

Internal cross-reference (to another assembly):

```asciidoc
xref:nodes/nodes/nodes-nodes-working.adoc#nodes-nodes-working[Working with nodes]
```

Internal cross-reference (to an anchor in the same or different doc):

```asciidoc
xref:nodes/nodes/nodes-nodes-working.adoc#nodes-nodes-rebooting_nodes-nodes-working[Rebooting a node]
```

External link:

```asciidoc
link:https://kubernetes.io/docs/concepts/architecture/nodes/[Kubernetes node documentation]
```

Defining an anchor:

```asciidoc
[id="nodes-nodes-rebooting_{context}"]
== Rebooting a node
```

The `{context}` variable is passed from the assembly to make anchors unique.

## Tables

```asciidoc
.Kubelet parameters
[cols="2,1,3",options="header"]
|===
| Parameter | Type | Description

| `maxPods`
| integer
| Maximum number of pods that can run on this node.

| `kubeReserved`
| object
| Resources reserved for Kubernetes system daemons.

| `systemReserved`
| object
| Resources reserved for OS system daemons.
|===
```

## Procedure Format

Every procedure module must follow this structure:

```asciidoc
// Module included in the following assemblies:
//
// * nodes/nodes/nodes-nodes-working.adoc

:_mod-docs-content-type: PROCEDURE

[id="nodes-nodes-viewing_{context}"]
= Viewing nodes in a cluster

You can view the nodes in your cluster to check their status and resource usage.

.Prerequisites

* You have access to the cluster as a user with the `cluster-admin` role.
* You have installed the OpenShift CLI (`oc`).

.Procedure

. Log in to the cluster:
+
[source,terminal]
----
$ oc login -u kubeadmin https://api.cluster.example.com:6443
----

. List all nodes:
+
[source,terminal]
----
$ oc get nodes
----
+
.Example output
[source,terminal]
----
NAME           STATUS   ROLES    AGE   VERSION
master-0       Ready    master   10d   v1.28.0
worker-0       Ready    worker   10d   v1.28.0
----

. View detailed information about a specific node:
+
[source,terminal]
----
$ oc describe node <node_name>
----

.Verification

* Verify the node status shows `Ready`:
+
[source,terminal]
----
$ oc get node worker-0 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
----
+
.Expected output
[source,terminal]
----
True
----
```

Key formatting rules for procedures:
- Use `.` for ordered steps (not `1.`, `2.`)
- Attach blocks to steps with `+` on a blank line
- Replacement variables use angle brackets: `<node_name>`
- Prerequisites and verification are mandatory sections

## Module vs Assembly Structure

**Module** -- A single, self-contained unit of content in `modules/`:
```
modules/nodes/proc_nodes-nodes-viewing.adoc
modules/nodes/con_nodes-nodes-about.adoc
modules/nodes/ref_nodes-nodes-resources.adoc
```

**Assembly** -- Pulls modules together into a page, lives in topic directories:
```
nodes/nodes/nodes-nodes-working.adoc
```

Assembly structure:

```asciidoc
:_mod-docs-content-type: ASSEMBLY
[id="nodes-nodes-working"]
= Working with nodes
:context: nodes-nodes-working

include::_attributes/common-attributes.adoc[]

// Concept: what nodes are
include::modules/nodes-nodes-about.adoc[leveloffset=+1]

// Procedure: viewing nodes
include::modules/nodes-nodes-viewing.adoc[leveloffset=+1]

// Reference: node resource table
include::modules/nodes-nodes-resources.adoc[leveloffset=+1]
```

## Common Mistakes

- **Missing `+` continuation** -- Content after a list step that is not attached with `+` renders as a new paragraph outside the list.
- **Wrong leveloffset** -- Using `leveloffset=+2` when you mean `+1` breaks the heading hierarchy.
- **Hardcoded product names** -- Use `{product-title}` instead of "OpenShift Container Platform".
- **Missing context variable** -- Anchors without `{context}` cause duplicate ID errors when the module is included in multiple assemblies.
- **Using `--` in code blocks** -- AsciiDoc interprets `--` as an em dash outside code blocks. Inside `----` delimited blocks it is fine.
- **Forgetting `ifdef` for distro-specific content** -- Content that only applies to OCP must be wrapped in `ifdef::openshift-enterprise[]`.
- **Bare URLs** -- Always wrap URLs in `link:` macro with display text.
- **Missing module header comment** -- Every module must list which assemblies include it in the comment header.
