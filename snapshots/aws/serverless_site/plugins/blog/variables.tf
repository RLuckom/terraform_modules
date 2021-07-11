variable name {
  type = string
}

variable region {
  type = string
}

variable account_id {
  type = string
}

variable admin_site_resources {
  type = object({
    default_styles_path = string
    default_scripts_path = string
    header_contents = string
    footer_contents = string
    site_title = string
    site_description = string
    aws_script_path = string
    lodash_script_path = string
    exploranda_script_path = string
  })
  default = {
    aws_script_path = ""
    lodash_script_path = ""
    exploranda_script_path = ""
    default_styles_path = ""
    default_scripts_path = ""
    header_contents = "<div class=\"header-block\"><h1 class=\"heading\">Private Site</h1></div>"
    footer_contents = "<div class=\"footer-block\"><h1 class=\"footing\">Private Site</h1></div>"
    site_title = "running_material.site_title"
    site_description = "running_material.site_description"
  }
}

variable plugin_config {
  type = object({
    domain = string
    bucket_name = string
    upload_root = string
    api_root = string
    aws_credentials_endpoint = string
    hosting_root = string
    source_root = string
    authenticated_role = object({
      arn = string
      name = string
    })
  })
}

variable i18n_config_values {
  type = any
  default = {
    postMetadata =  {
      placeholders = {
        trails = "Trails (comma-separated)"
        author = "Author"
        title = "Title"
        footnoteTitle = "Footnote Title"
        id = "Type a new post id, then press Enter"
      }
    }
    saveState = {
      unmodified = "Unmodified"
      unsaved = "Unsaved"
      modified = "Changed"
    }
    publishState = {
      mostRecent = "Published"
      unpublished = "Unpublished"
      modified = "Changed"
      unknown = "Unknown"
    }
    postActions = {
      unpublish = "Unpublish"
      publish = "Publish"
      save = "Save"
      edit = "Edit"
      delete = "Delete"
      toIndex = "Back"
      new = "New Post"
      addFootnote = "Add Footnote"
    }
    editActions = {
      deleteFootnote = "Delete Footnote"
      reallyDeleteFootnote = "Confirm Delete"
    }
    editing = "Editing"
    ui = {
      colonMarker = ":"
      textDescription = "Text Description"
      deselect = "Deselect"
      ok = "OK"
      cancel = "Cancel"
      required = "Required"
      createLink = "Create a link"
      linkTarget = "Link Target"
      toggleStrong = "Toggle stromg style"
      toggleEmphasis = "Toggle emphasis style"
      toggleCode = "Toggle code font"
      wrapBullet = "Wrap in bullet list"
      wrapOrdered = "Wrap in ordered list"
      wrapBlock = "Wrap in blockquote"
      changeParagraph = "Change to paragraph"
      plain = "Plain"
      changeCode = "Change to code block"
      code = "Code"
      changeHeading = "Change to Heading"
      level = "Level"
      insertHr = "Insert horizontal rule"
      hr = "Horizontal rule"
      addFnText = "Add footnote text"
      fnText = "Footnote text"
      fnRef = "Footnote Ref"
      insert = "Insert"
      heading = "Heading"
      type = "Type"
      ellipsis = "..."
      insertFn = "Insert Footnote"
      fn = "Footnote"
      insertImage = "Insert image"
      image = "Image"
      file = "File"
    }
  }
}

// plugin-specific variables below this line

variable coordinator_data {
  type = object({
    system_id = object({
      security_scope = string
      subsystem_name = string
    })
    routing = object({
      domain_parts = object({
        top_level_domain = string
        controlled_domain_part = string
      })
      domain = string
      route53_zone_name = string
    })
    // these can be set to "" if NA
    metric_table = string
    site_metrics_table = string
    lambda_log_delivery_prefix = string
    lambda_log_delivery_bucket = string
    cloudfront_log_delivery_prefix = string
    cloudfront_log_delivery_bucket = string
  })
}

variable subject_alternative_names {
  type = list(string)
  default = []
}

variable maintainer {
  type = object({
    name = string
    email = string
  })
  default = {
    name = ""
    email = ""
  }
}

variable nav_links {
  type = list(object({
    name = string
    target = string
  }))
  default = []
}

variable site_title {
  type = string
  default = "Test Site"
}

variable image_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable donut_days_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable markdown_tools_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable lambda_event_configs {
  type = list(object({
    maximum_event_age_in_seconds = number
    maximum_retry_attempts = number
    on_success = list(object({
      function_arn = string
    }))
    on_failure = list(object({
      function_arn = string
    }))
  }))
  default = []
}

variable logging_config {
  type = object({
    bucket = string
    prefix = string
    metric_table = string
  })
  default = {
    bucket = ""
    prefix = ""
    metric_table = ""
  }
}

locals {
  blog_image_hosting_root = "/img/"
  blog_image_hosting_prefix = "img/"
  blog_post_hosting_root = "/posts/"
  blog_post_hosting_prefix = "posts/"
  plugin_image_hosting_prefix = "${var.plugin_config.hosting_root}img/"
  plugin_post_hosting_prefix = "${var.plugin_config.hosting_root}posts/"
  file_prefix = trim(var.plugin_config.source_root, "/")
  edit_styles_path = "${local.file_prefix}/assets/styles/editor.css"
  plugin_default_styles_path = "${local.file_prefix}/assets/styles/default.css"
  post_utils_js_path = "${local.file_prefix}/assets/js/post-utils-${filemd5("${path.module}/src/frontend/libs/post_utils.js")}.js"
  libs_js_path = "${local.file_prefix}/assets/js/pkg-${filemd5("${path.module}/src/frontend/libs/libs.js")}.js"
  prosemirror_setup_js_path = "${local.file_prefix}/assets/js/prosemirror-setup-${filemd5("${path.module}/src/frontend/libs/prosemirror-setup.js")}.js"
  plugin_config = {
    posts_table = local.posts_table_name
    site_metrics_table = var.coordinator_data.site_metrics_table
    table_region = var.region
    website_bucket = module.blog_site.website_bucket_name
    blog_image_hosting_root = local.blog_image_hosting_root
    blog_image_hosting_prefix = local.blog_image_hosting_prefix
    blog_post_hosting_root = local.blog_post_hosting_root
    blog_post_hosting_prefix = local.blog_post_hosting_prefix
    operator_name = var.maintainer.name
    plugin_image_upload_path = "${trimsuffix(var.plugin_config.upload_root, "/")}/img/"
    plugin_post_upload_path = "${trimsuffix(var.plugin_config.upload_root, "/")}/posts/"
    plugin_image_hosting_path = "${trimsuffix(var.plugin_config.hosting_root, "/")}/img/"
    plugin_post_hosting_path = "${trimsuffix(var.plugin_config.hosting_root, "/")}/posts/"
    plugin_image_hosting_prefix = local.plugin_image_hosting_prefix
    plugin_post_hosting_prefix = local.plugin_post_hosting_prefix 
  }
  default_css_paths = [
    var.admin_site_resources.default_styles_path,
    local.plugin_default_styles_path,
  ]
  index_css_paths = [
  ]
  edit_css_paths = [
    local.edit_styles_path
  ]
  default_deferred_script_paths = [
    var.admin_site_resources.default_scripts_path,
  ]
  default_script_paths = [
    local.libs_js_path,
    local.post_utils_js_path,
  ]
  index_script_paths = [
  ]
  edit_script_paths = [
    local.prosemirror_setup_js_path,
  ]
}

output files {
  value = module.ui.files 
}

output plugin_config {
  value = {
    name = var.name
    slug = "manage blog posts"
  }
}
