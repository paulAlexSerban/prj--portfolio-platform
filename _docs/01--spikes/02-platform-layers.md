A platform is usually split into layers, and each layer has its own owner, change cadence, and blast radius. This repo uses one folder per layer under `layers/`.

| Layer | Folder | What it holds | Change cadence | Blast radius |
| --- | --- | --- | --- | --- |
| Foundation (landing zone) | `layers/01-foundation` | AWS accounts, IAM, networking, DNS zone, Terraform state bucket | Rare | High |
| Compute | `layers/02-compute` | The k3s node, node groups, storage classes, Ansible | Occasional | High |
| Platform services | `layers/03-platform-services` | Ingress, cert-manager, Argo CD, observability agents | Occasional | Medium. They run on the cluster and serve every workload |
| Delivery | `layers/04-delivery` | CI helpers, image registry wiring, deploy triggers, Argo CD app-of-apps root | Frequent | Medium |
| Workloads (consumers) | `layers/05-workloads` | Deploy definitions for sites, the WordPress preview, and later the quiz API. Application source stays in product repos | Frequent | Low, limited to one consumer |
| Cross-cutting | `layers/06-cross-cutting` | Cost tracking, security and secrets. Documentation lives in `_docs/` | With the thing it describes | Varies |

Shared Terraform modules live in `modules/terraform/`, outside any one layer, because more than one layer calls them.

In Kubernetes terms, the cluster is the platform boundary, a namespace is the usual isolation unit for one workload in one environment, and an Argo CD AppProject can group the apps that belong to one owner or client.

## Naming conventions (guidance)

These patterns are a starting point, not a rule. Rename a consumer, a folder, or a product repo when a clearer name exists. What matters is that the names you do use can be traced from the product repo to DNS to the bill.

Each consumer has several names, one per layer, and they should all derive from the same base. A common scheme:

| Layer | Pattern | Example |
| --- | --- | --- |
| This repo | one platform repo, folders under `layers/` | `layers/05-workloads` |
| Product repo | whatever the product is called | `prj--personal-portfolio--v3` |
| Workload ID | short kebab-case, no environment | `blog`, `news-feed`, `wp-preview` |
| Environment | `prod`, `staging`, `preview`, `dev` | `staging` |
| Hostname | `<workload>.paulserban.eu` for your own properties, `<env>.<client>.paulserban.eu` for client previews | `blog.paulserban.eu`, `staging.<client>.paulserban.eu` |
| Kubernetes namespace | `<workload>-<env>` | `wp-preview-staging` |
| Argo CD app | same as namespace | `wp-preview-staging` |
| S3 bucket | `<org>-<workload>-<env>-<suffix>` (S3 names are global) | `pserban-blog-prod-7f3a` |
| Terraform state key | `<layer>/<stack>/<env>.tfstate` for new stacks. The DNS zone already uses `portfolio-platform/terraform.tfstate` | `05-workloads/static-sites/prod.tfstate` |
| Tags | `project`, `env`, `owner`, `cost-center` on everything | `project=blog` |

The tenant (who the consumer belongs to) is the piece people most often leave implicit. Your own properties are one tenant, and each client or marketing site should be its own tenant, so cost reports and access rules can be split by it later. Using the workload ID as the cost-allocation tag makes the monthly cost-per-project report in Phase 6 work without extra mapping. A client tenant can use a placeholder such as `<client>` until the real name is public.

Two rules keep this manageable: never put the environment in a hostname for production (it should be the apex or a clean subdomain), and never let a client name appear in a public bucket or repo name unless you intend it to be public.
