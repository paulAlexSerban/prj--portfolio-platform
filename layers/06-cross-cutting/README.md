# Cross-cutting

Owner: platform. Change cadence: follows the thing it describes. Blast radius: varies.

Concerns that apply to every layer.

- `cost/`: tag taxonomy, AWS Budgets, and the local observability hub (Compose stack, collectors, dashboards).
- `security/`: secrets (SSM Parameter Store or SOPS) and policies. Nothing secret is committed in plain text.

Ideas, spikes, plans, and ADRs stay in `_docs/` at the repo root.
