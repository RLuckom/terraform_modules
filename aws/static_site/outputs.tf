output "cert_arn" {
  value = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output "logging_bucket" {
  value = module.logging_bucket
}

output "website_bucket" {
  value = module.website_bucket
}

