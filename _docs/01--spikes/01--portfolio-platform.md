# Portfolio Platform: Solution, Platform and Delivery Plan

Owner: Paul · Version 0.1 (draft for review) · 30 Oct 2026 · Status: ready for Phase 0 sign-off

## 1. Goal and Objectives

**Goal.** Run every paulserban.eu property, client preview and demo workload on one reproducible, low-cost, observable AWS platform that is defined entirely as code, deployed from Git, and doubles as a public showcase of platform and DevOps engineering.

**Objectives (SMART).**

| ID  | Objective                                                                    | Measure of success                                                                            |
| --- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| O1  | Migrate portfolio, blog, news-feed and quiz to S3 + CloudFront + Route 53    | All four live on the new stack, zero downtime cutover, old hosting decommissioned             |
| O2  | Provision all infrastructure with Terraform, state in S3 with native locking | `terraform plan` clean on main; no manual console changes; no DynamoDB lock table             |
| O3  | Reusable static-site module for marketing sites                              | A new site goes live in under 30 minutes from a spec                                          |
| O4  | Host WordPress preview at staging.{{CLIENT_NAME}}.paulserban.eu              | Reachable over HTTPS via CloudFront, SSH only from allowlisted IPs, noindex enforced          |
| O5  | Single-node Kubernetes plus Argo CD with GitOps deploys                      | A push to a watched Git repo reaches the cluster without manual steps, target under 5 minutes |
| O6  | Local observability hub with cost tracking                                   | Daily cost per project visible; budget alerts fire before month-end overrun                   |
| O7  | Analytics and SEO baseline                                                   | Cloudflare beacon reporting views; sitemaps indexed in Google Search Console and Bing         |
| O8  | Disposable demo machines (prj--demo-machines) integrated                     | Provision, connect via VS Code, see cost estimate, destroy; auto-expiry in place              |
| O9  | Spec-driven delivery                                                         | Every epic has an approved spec, plan, task list and acceptance tests before code starts      |

**Non-goals.** Multi-region active-active, enterprise-grade HA for the preview or demo workloads, migrating client production sites, building a full SaaS backend (the API and database are optional, see Phase 8).

## 2. Scope, Constraints and Assumptions

**In scope:** DNS zone, static hosting, WordPress preview (SSR), single-node Kubernetes, Argo CD, CI/CD, TLS, observability, cost tracking, SEO configuration, analytics beacon, demo-machine tooling, documentation.

**Constraints**

- Solo engineer, part-time delivery; plan is sized for roughly 8 to 10 calendar weeks.
- Low monthly budget; every recurring cost needs a justification.
- Stack is fixed: Terraform, Kubernetes, AWS, GitHub, JavaScript/TypeScript, Python, Bash, Ansible.
- EU resident and EU audience: GDPR applies, so prefer cookieless analytics and EU regions.

**Assumptions (confirm in Phase 0)**

1. A1: Domain paulserban.eu is registered and its zone can be delegated to Route 53.
2. A2: The existing WordPress site can be exported from WP Engine (files plus database dump) and run as plain WordPress with MariaDB on one small node.
3. A3: A single AWS account is acceptable to start; a second sandbox account is preferable for demo machines.
4. A4: Primary region eu-central-1 (Frankfurt); CloudFront certificates must live in us-east-1.
5. A5: The observability hub runs on your local machine and pulls data from AWS; it is not a hosted service.
6. A6: An API and database may not be needed at launch; the decision is deferred to an ADR.

## 3. Architecture Assessment (Monolith vs Microservices)

The assessment is a decision record, not a preference. Criteria for splitting a workload into its own service:

- It needs independent scaling, or a different runtime or release cadence.
- It has a distinct failure domain you want isolated.
- Team boundaries justify it (not applicable for one engineer).

|   |   |   |
|---|---|---|
|Workload|Style|Rationale|
|Portfolio, blog, news-feed, marketing sites|Static (SSG)|No runtime, cheapest, fastest, most secure|
|Quiz app (React)|Static SPA|Client-only; SPA fallback routing on CloudFront|
|Optional API for quiz and portfolio|Modular monolith|One deployable with clear internal modules; extract a service only when a criterion above is met|
|WordPress preview|Monolith (as shipped)|Low traffic, disposable, single node|
|Platform services (Argo CD, ingress, cert-manager)|Off-the-shelf|Operated, not developed|

**Recommendation (ADR-002):** modular monolith by default. Microservices would add operational cost with no payoff for a single maintainer. If you want a microservices showcase, add one small worker service later as a deliberate, time-boxed Phase 8 extension.

## 4. Target Platform Design

### 4.1 Platform overview

- **Static tier:** per-site S3 bucket (private) + CloudFront with Origin Access Control + ACM certificate + Route 53 alias records. Deploys come from GitHub Actions, not Argo CD.
- **Compute tier:** one EC2 instance (ARM, e.g. t4g.medium, scale up if memory stays above 80 percent) in a public subnet with Elastic IP, running k3s. It hosts Argo CD, ingress, cert-manager, and the WordPress preview with MariaDB.
- **Edge for staging:** CloudFront in front of the EC2 origin. The security group admits HTTP/HTTPS only from the CloudFront origin-facing managed prefix list (watch the security-group rule quota) and a secret origin header is checked at ingress.
- **State and DNS:** S3 bucket for Terraform state, Route 53 hosted zone for paulserban.eu.
- **Observability and cost:** local hub plus AWS Budgets and cost-allocation tags.

**Why k3s on EC2 rather than EKS:** EKS charges a fixed control-plane fee per cluster before any worker costs, which is disproportionate for a showcase cluster. k3s is real, CNCF-conformant Kubernetes with a small footprint and is sufficient to demonstrate GitOps. Revisit EKS only if you want to showcase it specifically (ADR-003).

### 4.2 Terraform design

- **State:** S3 backend with native state locking (`use_lockfile = true`, Terraform 1.10 or newer). No DynamoDB table. Enable bucket versioning, SSE (KMS or S3-managed), block public access, and a lifecycle rule for old versions.
- **Layout:** one state per stack, placed in the layer that owns it, to keep blast radius small. `layers/01-foundation/bootstrap` creates the state bucket. `layers/01-foundation/terraform/dns-zone` is the hosted zone (its existing state key stays `portfolio-platform/terraform.tfstate`). Later stacks: `layers/02-compute/terraform/ec2-k3s-node`, `layers/05-workloads/terraform/static-sites`, and cost resources under `layers/06-cross-cutting/cost`. New state keys use `<layer>/<stack>/<env>.tfstate`. Demo machines stay in their own repo.
- **Modules:** `modules/terraform/` holds `static-site` (S3, OAC, CloudFront, ACM, Route 53 records, security-headers policy, SPA toggle), `dns-zone`, `ec2-k3s-node`, `cloudfront-origin-ec2`, `github-oidc-role`, `budget-alerts`.
- **Conventions:** pinned provider versions, `.terraform.lock.hcl` committed, mandatory tags (`project`, `env`, `owner`, `cost-center`), variables validated, outputs documented.
- **CloudFront Function** rewrites directory URLs to index.html for Astro output; SPA sites use 403/404 to index.html fallback instead.

### 4.3 Configuration management (Ansible)

Terraform creates infrastructure; Ansible configures the node. Keep the boundary strict. Playbooks and roles live in `layers/02-compute/ansible`.

- Roles: `base-hardening` (unattended upgrades, fail2ban, SSH settings, swap), `k3s`, `backup` (WordPress DB dump and uploads to S3), `node-exporter`.
- Inventory generated from Terraform outputs; playbooks idempotent and run in CI check mode.

### 4.4 GitOps with Argo CD

- GitOps lives in this repo. `layers/03-platform-services/gitops/platform` holds ingress, cert-manager, and monitoring agents. `layers/05-workloads/gitops/apps` holds the WordPress preview and an optional API. `layers/04-delivery/gitops/apps-root` is the app-of-apps (or ApplicationSet) entry.
- **Trigger path:** code push → GitHub Actions builds an ARM-compatible image → pushes to GHCR (or ECR) → CI commits the new image tag under `layers/` → Argo CD syncs. Add a GitHub webhook to Argo CD for near-instant sync; polling (about 3 minutes) is the fallback.
- Expose Argo CD at argocd.paulserban.eu behind TLS and an IP allowlist, with GitHub SSO and RBAC; disable the default admin account after setup.
- Static sites are deliberately outside Argo CD.

### 4.5 CI/CD (GitHub Actions)

- AWS access through OIDC role assumption; no long-lived access keys anywhere.
- Static sites: install, build, test, `s3 sync` with correct cache headers (long for hashed assets, short for HTML), then CloudFront invalidation of HTML paths only.
- Terraform: `fmt`, `validate`, `tflint`, security scan (Checkov or Trivy), and Infracost on pull request; plan posted to the PR; apply on merge to main behind a protected environment approval.

### 4.6 Networking and access

- SSH (port 22) only from an allowlist variable (`allowed_ssh_cidrs`). Preferred upgrade: AWS Systems Manager Session Manager so port 22 can be closed entirely. Provide a Bash helper that updates the allowlist when your home or office IP changes.
- Public HTTP/HTTPS only through CloudFront for staging; direct origin access is blocked.
- Argo CD and the Kubernetes API are never open to the world.

### 4.7 Secrets and security

- Secrets in SSM Parameter Store or SOPS with age; nothing in Git in plain text.
- MFA on root and admin users; least-privilege IAM per workflow; Dependabot or Renovate enabled; branch protection on main.
- Backups: nightly WordPress dump to S3 with lifecycle expiry; test restore once per quarter.

### 4.8 Observability and cost hub (local)

- Docker Compose stack on your machine, kept in `layers/06-cross-cutting/cost`: Grafana plus a small datasource layer (Prometheus or Postgres) fed by Python scripts that pull AWS Cost Explorer data (cache results, because each API request carries a small charge), CloudFront metrics and node metrics.
- Dashboards: spend per project tag, per service, 30-day forecast, budget burn.
- Guardrails: AWS Budgets with email alerts at 50, 80 and 100 percent; Infracost in pull requests so cost is reviewed before apply.
- Site health and uptime: CloudFront metrics plus an external uptime check on key URLs.

### 4.9 Analytics and SEO

- **Views:** Cloudflare Web Analytics beacon (cookieless; works without moving DNS to Cloudflare). Inject the snippet from a single shared Astro layout component using an environment variable for the token.
- **SEO baseline per site:** `@astrojs/sitemap`, robots.txt, canonical URLs, Open Graph and Twitter tags, JSON-LD (Person, Article, BreadcrumbList), RSS for blog and news-feed, 301 redirects from old URLs, performance budget enforced by Lighthouse CI.
- **Indexing:** Google Search Console and Bing Webmaster verification via DNS TXT records managed in Terraform; submit sitemaps; optionally ping IndexNow on deploy.
- **Staging protection:** `X-Robots-Tag: noindex, nofollow` via CloudFront response-headers policy, plus basic auth or a shared secret on the WordPress preview.

### 4.10 Demo machines (prj--demo-machines)

- Keeps its own repo and Terraform root per provider (AWS, GCP) sharing the tagging and module conventions of this platform.
- Capabilities: provision on demand, VS Code Remote-SSH config generated automatically, SSH limited to your current IP, pre-apply cost estimate (hourly rate times planned hours, using Infracost or provider price data), mandatory time-to-live with auto-shutdown and a destroy command.
- Prefer running in a separate sandbox AWS account so a forgotten VM cannot affect production.

## 5. Repository Map

This repository is the platform codebase. It is one repo, split by layer. Application source stays in product repositories and is deployed through the workload layer. Folder names below are the ones in use; they are a working layout, not a strict naming scheme.

```
layers/
  01-foundation/          accounts, IAM, DNS zone, Terraform state bucket
  02-compute/             k3s node Terraform and Ansible
  03-platform-services/   ingress, cert-manager, Argo CD, monitoring agents
  04-delivery/            CI helpers and the Argo CD app-of-apps root
  05-workloads/           per-consumer deploy definitions, no application source
  06-cross-cutting/       cost, security, secrets
modules/terraform/        shared Terraform modules
_docs/                    ideas, spikes, plans, ADRs
```

| External repo | Contents | How it lands |
| --- | --- | --- |
| `prj--personal-portfolio--v3` | portfolio, blog, news-feed, quiz | S3 + CloudFront, defined under `layers/05-workloads` |
| `prj--marketing-sites` | one folder per marketing site | S3 + CloudFront |
| `prj--wp-preview` | WordPress content and image | k3s via `layers/05-workloads/gitops` |
| `prj--demo-machines` | disposable demo machines | its own Terraform; shares tags and module conventions |

Those product repo names are examples. Rename them freely.

## 6. Spec-Driven Development and Project Management

**Workflow per epic:** Constitution (principles, constraints) → Spec (what and why, user stories, acceptance criteria in Given/When/Then) → Plan (technical approach, ADRs) → Tasks (small, ordered, independently verifiable) → Implement → Verify against the spec → Retro.

**Artifacts** (kept in `_docs/`):

- `_docs/constitution.md`: non-negotiables such as everything as code, no long-lived keys, tag everything, cost reviewed before apply.
- `_docs/02--plans/`: `spec.md`, `plan.md`, and `tasks.md` for each epic, plus the roadmap and the RAID log.
- `_docs/03--adrs/`: one ADR per significant decision, in MADR format.

**Practices**

- GitHub Projects Kanban board with WIP limit of 2; one milestone per phase; epics as parent issues, tasks as sub-issues.
- Definition of Ready: spec approved, acceptance criteria testable, dependencies identified.
- Definition of Done: merged via PR, CI green, deployed, acceptance criteria demonstrated, docs and runbook updated, cost impact recorded.
- Trunk-based development, short-lived branches, Conventional Commits, PR templates linking the spec.
- Estimate in ranges, review the plan at the end of each phase, and keep a decision log.
- Task runner (`just` or `make`) in every repo so common commands are identical: `make plan`, `make deploy`, `make test`.

## 7. Phased Roadmap

Durations are indicative for part-time work and assume phases 2 and 7 can overlap.

### Phase 0: Foundations and Specs (about 3 to 5 days)

**Goal:** agree what is being built and how.

- Write the constitution, this plan as roadmap, and ADR-001 (single platform repo, layered), ADR-002 (monolith first), ADR-003 (k3s over EKS), ADR-004 (analytics and privacy) under `_docs/`.
- Confirm assumptions A1 to A6 and inventory current hosting, DNS records and URLs for redirects.
- Set up GitHub org conventions, project board, labels, PR templates.
- **Exit criteria:** specs approved; backlog created; risks logged.

### Phase 1: Terraform Bootstrap and DNS (about 1 week)

**Goal:** safe base for everything else.

- Create AWS account hardening (MFA, billing alerts, IAM Identity Center or admin role), then a bootstrap stack for the state bucket with native locking.
- Configure remote backend, then `dns-zone` stack: Route 53 hosted zone for paulserban.eu; lower TTLs on existing records ahead of cutover; delegate nameservers when ready.
- GitHub OIDC role and baseline Terraform CI (fmt, validate, tflint, scan, plan on PR).
- **Exit criteria:** plan and apply run from CI; state versioned; no static credentials exist.

### Phase 2: Static Hosting Module and Portfolio Migration (about 1 to 2 weeks)

**Goal:** O1 and O3.

- Build and test the `static-site` module on a throwaway subdomain; add ACM (us-east-1), OAC, response-headers policy, CloudFront Function, www and apex redirects.
- Add `deploy.yml` workflows per site in `prj--personal-portfolio--v3`, building each of `sites/portfolio`, `sites/blog`, `sites/news-feed` and `apps/quiz` with path-filtered triggers.
- Cut over site by site (blog first as lowest risk, portfolio last); keep old hosting for a rollback window.
- **Exit criteria:** four sites live over HTTPS, redirects verified, Lighthouse scores recorded, rollback documented.

### Phase 3: Marketing Sites Pipeline (about 3 to 5 days)

**Goal:** a repeatable path for new sites.

- Create `prj--marketing-sites` with a shared Astro layout, a site template and a `new-site` script that scaffolds code, Terraform variables and workflow.
- Launch the first marketing site end to end as the acceptance test.
- **Exit criteria:** new site from spec to production in under 30 minutes.

### Phase 4: Compute Foundation and WordPress Preview (about 1 to 1.5 weeks)

**Goal:** O4.

- Terraform: VPC (or default VPC with locked-down groups), security group with SSH from `allowed_ssh_cidrs` only, Elastic IP, EC2 ARM instance with encrypted EBS, IAM instance profile for backups and SSM.
- Ansible: hardening plus k3s install; verify with a smoke playbook.
- Import the WordPress export (files and DB) into MariaDB and WordPress pods with persistent volumes; run search-replace for the new hostname.
- Route 53 record, CloudFront distribution with EC2 origin, noindex header, secret origin header, basic auth.
- Nightly backup job and a documented restore test.
- **Exit criteria:** staging.{{CLIENT_NAME}}.paulserban.eu works over HTTPS; direct origin access blocked; restore tested.

### Phase 5: Argo CD and GitOps (about 1 week)

**Goal:** O5.

- Install Argo CD (trim unused components for memory). Add the app-of-apps under `layers/04-delivery/gitops/apps-root` and install ingress and cert-manager from `layers/03-platform-services/gitops/platform`.
- Move the WordPress preview under Argo CD management.
- Wire the CI-to-gitops image-tag update and the GitHub webhook; configure SSO, RBAC and IP allowlist.
- **Exit criteria:** a code push reaches the cluster automatically; rollback by Git revert demonstrated; time-to-deploy recorded.

### Phase 6: Observability and Cost Hub (about 1 week)

**Goal:** O6.

- Define the tag taxonomy and activate cost-allocation tags; create AWS Budgets and alerts.
- Build the local Compose stack and Python collectors; create dashboards for cost, traffic and node health.
- Add Infracost to Terraform pull requests.
- **Exit criteria:** monthly cost visible per project; alert tested; monthly review ritual scheduled.

### Phase 7: SEO and Analytics (about 3 to 5 days, can overlap with Phase 2)

**Goal:** O7.

- Add the shared SEO component set and Cloudflare beacon to all Astro sites; generate sitemaps and robots files.
- Add Search Console and Bing verification records in Terraform; submit sitemaps; add Lighthouse CI budgets.
- **Exit criteria:** pages indexed, beacon counts visible, structured-data tests pass.

### Phase 8: Optional API and Database (about 1 week, decision gate)

**Goal:** only if a spec justifies it.

- Decision gate: write a spec listing the features that need server-side state. If the need is simple, prefer serverless (Lambda behind a function URL or API Gateway plus DynamoDB); if relational data is required, run a modular-monolith API with PostgreSQL on the k3s node, deployed through Argo CD.
- **Exit criteria:** spec approved before any code; endpoint, schema, backup and cost documented.

### Phase 9: Demo Machines Integration (about 1 week)

**Goal:** O8.

- Align `prj--demo-machines` with the shared module conventions, tags and CI; add TTL auto-shutdown and the pre-apply cost estimate; document the VS Code Remote-SSH workflow.
- Use a sandbox account or at least separate IAM role and budget.
- **Exit criteria:** end-to-end demo: provision, connect, estimate matches actual within tolerance, destroy.

### Phase 10: Hardening and Handover (about 3 to 5 days)

- Runbooks (deploy, rollback, restore, rotate secrets, change SSH allowlist), architecture diagram, README for every repo, final cost report, retrospective, and a public write-up (suits the blog and your LinkedIn plan).
- **Exit criteria:** all objectives O1 to O9 verified against their measures; backlog for v2 captured.

## 8. Milestones Summary

|   |   |   |
|---|---|---|
|Milestone|After phase|Demonstrable outcome|
|M0 Specs approved|0|Plan and ADRs signed off|
|M1 Platform base|1|Terraform CI, remote state, DNS zone|
|M2 Sites migrated|2|Four properties on S3 + CloudFront|
|M3 Site factory|3|Marketing site shipped from template|
|M4 Preview live|4|WordPress preview behind CloudFront|
|M5 GitOps live|5|Push-to-deploy via Argo CD|
|M6 Cost visible|6|Dashboards and budget alerts|
|M7 Discoverable|7|Indexed and measured|
|M8 Demo ready|9|Disposable VM with cost estimate|
|M9 Done|10|All objectives verified|

## 9. Rough Monthly Cost Model

Treat these as planning ranges and verify against current AWS pricing and the Infracost output in Phase 1.

- Route 53 hosted zone plus queries: low single-digit dollars.
- S3, CloudFront for low-traffic sites: typically within or near the free tier; a few dollars at most.
- EC2 ARM node plus EBS and Elastic IP: the largest line item, in the tens of dollars per month; reduce with a Savings Plan or by stopping it outside working windows if preview availability allows.
- Backups and logs in S3: negligible.
- Demo machines: pay per hour, controlled by TTL and budgets.
- Cost Explorer API calls from the hub: small, controlled by caching.

## 10. Risks and Mitigations

|   |   |   |
|---|---|---|
|Risk|Impact|Mitigation|
|DNS cutover breaks email or subdomains|High|Inventory all records first, lower TTLs, import existing records into Terraform, cut over per site|
|Single node fails or runs out of memory|Medium|Right-size, trim Argo CD, nightly backups, rebuild from Terraform and Ansible, documented restore|
|State bucket loss or corruption|High|Versioning, restricted access, separate bootstrap, periodic copy|
|Cost overrun from forgotten demo VMs|Medium|TTL auto-shutdown, budgets, separate account, daily cost dashboard|
|WordPress compromised (internet-exposed)|Medium|CloudFront-only origin, basic auth, updates via image rebuilds, no client data beyond preview content|
|Scope creep (API, microservices, EKS)|Medium|Decision gates and ADRs; anything new needs a spec|
|GDPR and analytics concerns|Low|Cookieless beacon, privacy note on each site|
|Solo bandwidth|Medium|WIP limit, phase exit criteria, phases 2 and 7 only overlap when capacity exists|

## 11. Open Questions

1. Is the WordPress preview content allowed to leave WP Engine, and does it use plugins that need licensed or vendor-specific features?
2. Should the observability hub stay strictly local, or is a small always-on collector acceptable?
3. Single AWS account or an Organization with separate production and sandbox accounts?
4. Which container registry do you prefer: GHCR (free, simple) or ECR?
5. Is the quiz app fully client-side today, or does it already depend on an API or database?

## 12. Immediate Next Steps

1. Answer the open questions above and confirm assumptions A1 to A6.
2. Keep this document in `_docs/01--spikes/` as the roadmap until it moves to `_docs/02--plans/`.
3. Start Phase 0 and open the milestone and issues for Phase 1.