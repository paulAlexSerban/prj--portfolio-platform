# Compute

Owner: platform. Change cadence: occasional. Blast radius: high.

The k3s node, its node groups, and storage classes. Terraform will live in `terraform/ec2-k3s-node`. Ansible (base hardening, k3s, backups, node exporter) will live in `ansible/`.

Terraform creates the node. Ansible configures it. Keep that boundary.
