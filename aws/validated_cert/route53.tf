data "aws_route53_zone" "selected" {
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  count = length(var.subject_alternative_names) + 1
  name            = aws_acm_certificate.cert.domain_validation_options.*.resource_record_name[count.index]
  records         = [aws_acm_certificate.cert.domain_validation_options.*.resource_record_value[count.index]]
  type            = aws_acm_certificate.cert.domain_validation_options.*.resource_record_type[count.index]
  zone_id         = data.aws_route53_zone.selected.zone_id
  ttl             = 60
}
