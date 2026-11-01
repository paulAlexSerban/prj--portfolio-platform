# Delivery

Owner: platform. Change cadence: frequent. Blast radius: medium.

CI helpers, image registry wiring, and deploy triggers. The Argo CD app-of-apps entry will live in `gitops/apps-root/`. Workflow files that GitHub Actions must see stay under `.github/workflows/` at the repo root.

`.github/workflows/terraform-ci.yaml` runs `fmt`, `validate`, and `tflint` on pull requests. It does not talk to AWS. Plan and apply stay on your machine.
