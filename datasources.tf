data oci_core_images "default_images" {
  compartment_id = var.compartment_id

  filter {
    name   = "display_name"
    regex  = true
    values = [var.default_image_name]
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}
