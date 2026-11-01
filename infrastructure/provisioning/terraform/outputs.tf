output "zone_id" {
  description = "ID of the Route 53 hosted zone."
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Name servers assigned to the hosted zone. Use these to switch domain delegation."
  value       = aws_route53_zone.this.name_servers
}
