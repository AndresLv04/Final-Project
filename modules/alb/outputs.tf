# ===================================
# ALB core outputs
# ===================================

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID associated to the ALB"
  value       = aws_lb.main.zone_id
}

# ===================================
# Target group / listeners
# ===================================

output "portal_target_group_arn" {
  description = "Target group ARN for the patient portal ECS service"
  value       = aws_lb_target_group.portal.arn
}

output "http_listener_arn" {
  description = "HTTP listener ARN (port 80)"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN (port 443). Empty string when HTTPS is disabled."
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : ""
}

# ===================================
# Hostname / URL
# ===================================

output "portal_hostname" {
  description = "Hostname to access the portal (Route53 record if created, otherwise ALB DNS name)"
  value = (
    var.route53_zone_id != "" && var.domain_name != ""
  ) ? aws_route53_record.alb[0].fqdn : aws_lb.main.dns_name
}

output "portal_url" {
  description = "Base URL for the patient portal behind the ALB"
  value       = "${local.portal_scheme}://${local.portal_host}"
}