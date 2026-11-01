---
name: Platform repo restructure
overview: Reorganise the repo from a single-project layout into a layered platform codebase (core only), keep the existing Terraform state untouched, and update the two spike docs so repo and folder names reflect the new structure.
todos:
  - id: move-tf
    content: git mv Terraform and bootstrap script into layers/01-foundation; remove empty dirs
    status: completed
  - id: state-safe
    content: Keep backend key unchanged, re-init and confirm terraform plan shows no changes
    status: completed
  - id: tooling
    content: Update makefile (STACK var), bootstrap script, README and other path references
    status: completed
  - id: stubs
    content: Add layer README stubs and modules/terraform placeholder
    status: completed
  - id: docs
    content: Update 01--portfolio-platform.md and 02-platform-layers.md for new structure and naming guidance
    status: completed
  - id: verify
    content: Run fmt/validate/plan, make -n checks, and grep for stale paths and repo names
    status: completed
isProject: false
---

# Platform repo restructure

## Decisions taken
- Scope: platform core only. Terraform, Ansible, GitOps (Argo CD), observability hub, CI, specs/ADRs live here. Site source, quiz, marketing sites, wp-preview app code and demo-machines stay in their own repos.
- Layout: top-level folders follow the platform layers from [_docs/01--spikes/02-platform-layers.md](_docs/01--spikes/02-platform-layers.md).
- Naming conventions in the spikes are guidance, not strict. The docs will be edited to match what is actually built.

## Target structure

```
.github/workflows/            # CI must sit at repo root (added in later phases)
_docs/                        # cross-cutting: ideas, spikes, plans, adrs (unchanged)
layers/
  01-foundation/              # accounts, IAM, DNS zone, state bucket
    terraform/dns-zone/       # current route53 zone + records
    bootstrap/                # state-bucket bootstrap script
    README.md
  02-compute/                 # k3s node
    terraform/ec2-k3s-node/   # placeholder
    ansible/                  # roles: base-hardening, k3s, backup, node-exporter
  03-platform-services/       # ingress, cert-manager, Argo CD, monitoring agents
    gitops/platform/
  04-delivery/                # CI helpers, image registry, deploy triggers
    gitops/apps-root/         # Argo CD app-of-apps entry
  05-workloads/               # per-consumer definitions (no app source)
    terraform/static-sites/
    gitops/apps/wp-preview/
  06-cross-cutting/
    cost/                     # budgets, tag taxonomy, observability hub (compose + collectors)
    security/                 # secrets (SOPS/SSM), policies
modules/terraform/            # shared modules: static-site, dns-zone, github-oidc-role, budget-alerts...
scripts/
  tools/                      # setup-local-project-deps.bash (stays)
  one-time/                   # export-route53-dns-zone-config.bash (stays; bootstrap moves to layer)
makefile  README.md  .env.example  .tflint.hcl  .terraform-version  .gitleaks.toml
```

Only folders that have content today are created for real (`01-foundation`). Later layers get a short `README.md` stub stating purpose, owner and change cadence, so the structure is visible without empty dirs.

## Steps

1. Move the existing Terraform with `git mv`
   - `infrastructure/provisioning/terraform/*` to `layers/01-foundation/terraform/dns-zone/` (keeps `.terraform.lock.hcl`).
   - `scripts/one-time/bootstrap-terraform-state-bucket.bash` to `layers/01-foundation/bootstrap/`.
   - Remove the empty `infrastructure/` and `tools/` dirs.
2. Keep Terraform state safe
   - Leave `key = "portfolio-platform/terraform.tfstate"` in [versions.tf](infrastructure/provisioning/terraform/versions.tf) unchanged, so no state migration is needed.
   - Delete the stale local `.terraform/` and re-run `terraform init` from the new path; confirm `terraform plan` shows no changes.
   - Future stacks use `<layer>/<stack>/<env>.tfstate` keys, per the spike.
3. Update tooling paths
   - [makefile](makefile): introduce `STACK ?= layers/01-foundation/terraform/dns-zone`; all `terraform-*` targets use `-chdir=$(STACK)`; bootstrap target points to the new script path; `terraform-output` still writes `.env.*`.
   - Fix path references inside the moved bootstrap script, [.tflint.hcl](.tflint.hcl) if it uses paths, and [README.md](README.md).
4. Add layer stubs and `modules/terraform/` placeholder `README.md` files (purpose, owner, change cadence, blast radius, as described in the layers doc).
5. Update the spike docs
   - [_docs/01--spikes/01--portfolio-platform.md](_docs/01--spikes/01--portfolio-platform.md):
     - Section 5 "Repository Map": replace the 9-repo table with this platform repo (layers tree above) plus a short table of external repos (portfolio sites, marketing-sites, wp-preview source, demo-machines) and what they deploy through.
     - Section 4.2 Terraform layout: stacks mapped to layer paths instead of flat `bootstrap/dns/...`; modules path `modules/terraform/`.
     - Sections 4.3, 4.4, 6, 7, 8: replace references to `prj--platform-infra`, `-ansible`, `-gitops`, `-specs`, `-observability-hub` with the new paths (`layers/02-compute/ansible`, `layers/03-platform-services/gitops`, `_docs/`, `layers/06-cross-cutting/cost`). ADR-001 becomes "single platform repo, layered".
   - [_docs/01--spikes/02-platform-layers.md](_docs/01--spikes/02-platform-layers.md): turn the naming table into guidance ("Repo" row reflects the platform repo; add the folder-per-layer mapping) and answer its closing question by adding a short "Naming conventions (guidance)" section.
6. Housekeeping
   - Update the two existing `.cursor/plans/*.md` path mentions only if they reference moved files.
   - Confirm `.gitignore` still covers `tmp/`, `.env*`, and `.terraform/` at the new depth.

## Verification
- `terraform fmt -check`, `terraform validate`, and `terraform plan` (no diff) from the new stack path with `.env` sourced.
- `make -n terraform-plan` and `make -n terraform-bootstrap-state-bucket` resolve to existing paths.
- Grep for the old `infrastructure/provisioning` path and old `prj--platform-*` repo names returns no stale references.

## Notes
- `terraform plan` needs live AWS credentials and network, so it will be run outside the sandbox.
- The unused `tools/` dir is empty today; it is dropped unless you want it kept.