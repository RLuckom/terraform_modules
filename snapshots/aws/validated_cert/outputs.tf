output "route53_zone" {
  value = {
    zone_id = data.aws_route53_zone.selected.zone_id
    name = data.aws_route53_zone.selected.name
  }
}

output "cert" {
  value = {
    domain_name = aws_acm_certificate.cert.domain_name
    subject_alternative_names = aws_acm_certificate.cert.subject_alternative_names
    id = aws_acm_certificate.cert.id
    arn = aws_acm_certificate.cert.arn
  }
}
