variable "cloudinit_multipart" {
  type    = list(any)
  default = []
}
variable "enable_cloudinit_multipart_mime" {
  type    = bool
  default = true
}

variable "parameters" {
  type    = map(any)
  default = {}
}

locals {

  enable_metadata = contains(keys(var.value.instance), "enable_metadata") ? var.value.instance.enable_metadata : false
  metadata        = local.enable_metadata ? var.value.instance.metadata : null

  enable_user_data = contains(keys(var.value.instance), "enable_user_data") ? var.value.instance.enable_user_data : false

  cloudinit_part = contains(keys(var.value.instance), "cloudinit_multipart") ? flatten([
    for k in var.value.instance.cloudinit_multipart : contains(keys(k), "file") ?
    {
      filename : k.filename
      content_type : k.content_type
      content : file(format("%s/%s", path.root, k.file))
    } : contains(keys(k), "templatefile") ?
    {
      filename : k.filename
      content_type : k.content_type
      content : templatefile(format("%s/%s", path.root, k.templatefile),
      merge([var.parameters, { env_keys = var.parameters }, contains(keys(k), "vars") ? k.vars : {}]...))
    } : contains(keys(k), "cloud-config") ?
    {
      filename : k.filename
      content_type : k.content_type
      content : format("#cloud-config\n%s", yamlencode(k.cloud-config))
    } : contains(keys(k), "content") ?
    {
      filename : k.filename
      content_type : k.content_type
      content : k.content
    } : {}
  ]) : []

  enable_cloudinit_multipart_mime = contains(keys(var.value.instance), "enable_cloudinit_multipart_mime") ? var.value.instance.enable_cloudinit_multipart_mime : true
  # sometimes: vm can run only first raw script  (without multipart mime)
  # enable_cloudinit_multipart_mime = false

  user_data = local.enable_user_data ? local.enable_cloudinit_multipart_mime ? base64encode(data.cloudinit_config.vm_config[0].rendered) : base64encode(data.cloudinit_config.vm_config[0].part[0].content) : ""

}

#
# cloudinit
#
data "cloudinit_config" "vm_config" {
  count         = length(local.cloudinit_part) > 0 ? 1 : 0
  gzip          = false
  base64_encode = false # true

  # Add any additional cloud-init configuration or scripts provided by the user
  dynamic "part" {
    for_each = local.cloudinit_part
    content {
      filename     = part.value.filename
      content_type = part.value.content_type
      content      = part.value.content
    }
  }
}
