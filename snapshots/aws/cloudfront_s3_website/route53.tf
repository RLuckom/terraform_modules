data "aws_route53_zone" "selected" {
  name         = local.routing.route53_zone_name
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

resource "aws_route53_record" "www_site_cname" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "www.${local.routing.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_cloudfront_distribution.website_distribution.domain_name]
}

resource "aws_route53_record" "site_a_record" {
  zone_id = data.aws_route53_zone.selected.id
  name    = local.routing.domain
  type    = "A"

  alias {
    zone_id = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    evaluate_target_health = true
  }
}
