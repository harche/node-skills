# OpenShift Documentation Contribution Guide

## Overview

OpenShift documentation lives in the `openshift/openshift-docs` repository. It uses **AsciiBinder** as the build toolchain and **AsciiDoc** as the markup language. Docs are published to https://docs.openshift.com.

There is also a markdown-converted mirror at `github.com/harche/openshift-docs-md` with an `AGENTS.md` index file for agent-friendly navigation. This is useful for reading and searching docs programmatically without dealing with AsciiDoc includes and conditionals.

## Repository Structure

```
openshift-docs/
  _topic_maps/            # Topic map YAML files that define the docs nav tree
  _distro_map.yml         # Maps distro keys to product names and branches
  modules/                # Reusable content modules (proc_, con_, ref_)
  nodes/                  # Node management assemblies
  machine_configuration/  # MCO and MachineConfig assemblies
  monitoring/             # Monitoring and alerting assemblies
  rest_api/               # API reference docs
  images/                 # Screenshots and diagrams
  snippets/               # Reusable text snippets
```

## Node-Relevant Doc Sections

The Node team primarily owns or contributes to:

- **`nodes/`** -- Node management, scheduling, pods, containers, jobs, DaemonSets, garbage collection, kernel parameters, resource management, cgroups, CPU manager, topology manager, NUMA-aware scheduling, node overcommitment, TLS security profiles, graceful shutdown, swap memory, node disruption policies
- **`machine_configuration/`** -- MachineConfig operator, MachineConfigPool, OS updates, node configuration, kernel arguments, extensions, certificate management, image-based upgrade
- **`monitoring/`** -- Monitoring stack config, alerting rules (node-level alerts), metric collection
- **`scalability_and_performance/`** -- Node tuning operator, low latency, huge pages, NUMA, performance profiles
- **`rest_api/node_apis/`** -- Node API reference (Node, RuntimeClass, etc.)

## AsciiDoc Basics for OpenShift Docs

See `docs/asciidoc-reference.md` for the full reference. Key points:

- Headings use `=` (one per level, starting at `=` for doc title)
- Code blocks use `[source,yaml]` delimiters with `----`
- Admonitions: `NOTE:`, `IMPORTANT:`, `WARNING:`, `TIP:`
- Conditional text uses `ifdef::openshift-enterprise[]` / `endif::[]`
- Cross-references use `xref:` with the assembly file path

## Content Types

OpenShift docs follow a **modular documentation** approach:

| Type | Prefix | Purpose |
|------|--------|---------|
| Concept | `con_` | Explains what something is and why it matters |
| Procedure | `proc_` | Step-by-step instructions for a task |
| Reference | `ref_` | Tables, lists, specs, API fields |

Assemblies pull modules together into a coherent page. See `docs/doc-structure.md` for details.

## PR Process for Docs

1. Fork `openshift/openshift-docs` and create a branch.
2. Make changes following the modular doc structure.
3. Build locally to verify rendering (see below).
4. Open a PR against the appropriate branch:
   - `main` -- next unreleased version
   - `enterprise-4.x` -- specific released version
5. Add the `peer-review-needed` label.
6. A docs team member reviews for style and structure.
7. A subject matter expert (SME) from the Node team reviews for accuracy.
8. After approvals, a docs maintainer merges.

**Branch targeting:** If your change applies to multiple versions, open the PR against the oldest applicable branch. The docs team backports or forward-ports as needed. Always note in the PR description which versions are affected.

**Labels to use:**
- `peer-review-needed` -- ready for docs peer review
- `SME-review-needed` -- needs subject matter expert review
- `nodes` or `machine-config` -- for team routing

## Building Docs Locally

```bash
# Clone the repo
git clone https://github.com/openshift/openshift-docs.git
cd openshift-docs

# Install dependencies (requires Ruby)
gem install ascii_binder

# Build all distros
asciibinder build

# Build a single distro (faster)
asciibinder build --distro openshift-enterprise

# Preview -- output lands in _preview/
# Open _preview/openshift-enterprise/latest/welcome/index.html
```

Alternatively, use the containerized build:

```bash
podman run --rm -v $(pwd):/docs:Z quay.io/openshift-cs/asciibinder asciibinder build
```

**Validation without building:** Use `asciidoctor` directly to check a single file:

```bash
asciidoctor --backend html5 --safe-mode safe modules/nodes/proc_nodes-example.adoc
```

## Style Guide Highlights

- Use **second person** ("you") not third person ("the user").
- Use **active voice**: "Configure the kubelet" not "The kubelet is configured."
- Use **present tense**: "The node restarts" not "The node will restart."
- Spell out numbers under 10, use digits for 10 and above.
- Use **bold** for UI elements: *Compute* > *Nodes*.
- Use `monospace` for CLI commands, file paths, API objects, field names.
- Use the product name on first reference: "Red Hat OpenShift Container Platform" then "OpenShift Container Platform" or just the product attribute `{product-title}`.
- Do not use contractions (don't, can't, won't).
- Every procedure must have: prerequisites, steps, verification.
- Use conditional directives (`ifdef`) for content that differs between OCP, OKD, and other distros.

## Cross-Referencing

When referencing other doc pages, use `xref:` with the path relative to the repo root:

```asciidoc
For more information, see xref:nodes/nodes/nodes-nodes-working.adoc#nodes-nodes-working[Working with nodes].
```

When referencing an external resource, use a standard URL:

```asciidoc
See the link:https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/[upstream kubelet documentation].
```

## Further Reading

- `docs/asciidoc-reference.md` -- AsciiDoc syntax reference for OpenShift docs
- `docs/doc-structure.md` -- Directory structure and module/assembly conventions
