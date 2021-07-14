resource aws_cognito_user_pool user_pool {
  name = "${var.system_id.security_scope}-${var.system_id.subsystem_name}-pool"

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false 
    required                 = true 
    string_attribute_constraints {
      min_length = 3
      max_length = 250
    }
  }
  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = <<EOF
Here we go! This email contains your login details for <a href="https://${var.protected_domain_routing.domain}/">${var.protected_domain_routing.domain}</a>

Your username is {username} and your temporary password is {####}

Note that if you are using terraform to set up the system for the first time, the complete system may
not have finished being set up at the time you received this email. The site may not work at all until
you see terraform complete successfully.

Terraform works additively (or, when deploying, subtractively). That means that if it completes some steps
before failing, either during the "apply" (create) or "destroy" steps, it will skip those steps the next time
it runs. Before entering 'yes' at the confirmation prompt, note the number of resources terraform says it will
create, update, and delete. If the run fails, try running it again. If the create / update / destroy numbers are
the same the next time, then you're stuck and further debugging is needed. If the numbers keep going down each time
you run terraform, then continue to run it until a run completes successfully. Initial failures can be caused by
terraform trying to delete or create a resource before the things it relies on are completely ready. If you give it
a few moments between runs, these things often resolve themselves. Note that certain resources may take up to 15 minutes
to be operational.
EOF
      email_subject = "Personal cloud system account created"
      sms_message = "Your username for https://${var.protected_domain_routing.domain}/ is {username} and your temporary password is {####}"
    }
  }
  auto_verified_attributes = ["email"]
}

resource aws_cognito_user_group user_group {
  name         = var.user_group_name
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource null_resource user {

  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the clutser
    command = "aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.user_pool.id} --username ${var.user_email} --user-attributes Name=email,Value=${var.user_email} && sleep 5 && aws cognito-idp admin-add-user-to-group --user-pool-id ${aws_cognito_user_pool.user_pool.id} --username ${var.user_email} --group-name ${aws_cognito_user_group.user_group.name}"
    environment = {
      AWS_SHARED_CREDENTIALS_FILE = var.aws_credentials_file
    }
  }
}

resource aws_cognito_user_pool_client client {
  name = "${var.system_id.security_scope}-${var.system_id.subsystem_name}-client"

  user_pool_id = aws_cognito_user_pool.user_pool.id

  allowed_oauth_flows = ["implicit", "code"]
  read_attributes = [
     "address", "birthdate", "email", "email_verified", "family_name", "gender", "given_name", "locale", "middle_name", "name", "nickname", "phone_number", "phone_number_verified", "picture", "preferred_username", "profile", "updated_at", "website", "zoneinfo"
  ]
  write_attributes = [
    "address", "birthdate", "email", "family_name", "gender", "given_name", "locale", "middle_name", "name", "nickname", "phone_number", "picture", "preferred_username", "profile", "updated_at", "website", "zoneinfo"
  ]
  access_token_validity = var.token_validities.access.value
  id_token_validity = var.token_validities.id.value
  supported_identity_providers = ["COGNITO"]
  generate_secret = true
  callback_urls = local.callback_urls
  logout_urls = local.logout_urls
  allowed_oauth_scopes = local.allowed_oauth_scopes
  allowed_oauth_flows_user_pool_client = local.allowed_oauth_flows_user_pool_client
  token_validity_units {
    access_token = var.token_validities.access.unit
    id_token = var.token_validities.id.unit
    refresh_token = var.token_validities.refresh.unit
  }
}

resource aws_cognito_user_pool_domain domain {
  domain    = local.cognito_domain
  certificate_arn = aws_acm_certificate.cert.arn
  user_pool_id    = aws_cognito_user_pool.user_pool.id
}

data aws_route53_zone selected {
  name         = var.protected_domain_routing.route53_zone_name
  private_zone = false
}

resource aws_route53_record cert_validation {
  name            = aws_acm_certificate.cert.domain_validation_options.*.resource_record_name[0]
  records         = aws_acm_certificate.cert.domain_validation_options.*.resource_record_value
  type            = aws_acm_certificate.cert.domain_validation_options.*.resource_record_type[0]
  zone_id         = data.aws_route53_zone.selected.zone_id
  ttl             = 60
}

resource aws_route53_record auth_a_record {
  name    = local.cognito_domain
  type    = "A"
  zone_id = data.aws_route53_zone.selected.id
  alias {
    evaluate_target_health = false
    name                   = aws_cognito_user_pool_domain.domain.cloudfront_distribution_arn
    # This zone_id is fixed
    zone_id = "Z2FDTNDATAQYW2"
  }
}

resource aws_acm_certificate cert {
  domain_name    = local.cognito_domain
  subject_alternative_names = []
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_acm_certificate_validation cert_validation {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}
