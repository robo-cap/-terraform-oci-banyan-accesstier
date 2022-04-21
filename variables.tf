variable "tenancy_ocid" {}

variable "compartment_ocid" {}

variable "compartment_id" {
  type        = string
  description = "ID of the compartment in which to create the resources"
}

variable "region" {
  type        = string
  description = "OCI region for the deployment"
}

# variable "user_ocid" {}

# variable "fingerprint" {}

# variable "private_key_path" {}

variable "vcn_id" {
  type        = string
  description = "ID of the VCN in which to create the Access Tier"
}

variable "healthcheck_cidr" {
  type        = string
  description = "CIDR block to allow health check connections from (recommended to use the VPC CIDR range)"
  default     = "0.0.0.0/0"
}

variable "management_cidr" {
  type        = string
  description = "CIDR block to allow SSH connections from"
  default     = "0.0.0.0/0"
}

variable "shield_cidr" {
  type        = string
  description = "CIDR blocks to allow Shield (Cluster Coordinator) connections to"
  default     = "0.0.0.0/0"
}

variable "shield_port" {
  type        = number
  description = "TCP port number to allow Shield (Cluster Coordinator) connections to"
  default     = 1
}

variable "command_center_cidr" {
  type        = string
  description = "CIDR block to allow Command Center connections to"
  default     = "0.0.0.0/0"
}

variable "trustprovider_cidr" {
  type        = string
  description = "CIDR block to allow TrustProvider connections to"
  default     = "0.0.0.0/0"
}

variable "managed_internal_cidr" {
  type        = string
  description = "CIDR block to allow managed internal services connections to"
  default     = "0.0.0.0/0"
}

# variable "public_subnet_ids" {
#   type        = list(string)
#   description = "IDs of the subnets where the load balancer should create endpoints"
# }

variable "public_subnet_id" {
  type        = string
  description = "ID of the subnet where the load balancer should create endpoint"
}

variable "private_subnet_id" {
  type        = string
  description = "ID of the subnet where the Access Tier should create instances"
}

variable "package_name" {
  type        = string
  description = "Override to use a specific version of netagent (e.g. `banyan-netagent-1.5.0`)"
  default     = "banyan-netagent"
}

variable "compute_shape" {
  type        = string
  description = "VM instance shape to use when creating Access Tier instances"
  default     = "VM.Standard.E4.Flex"
}

variable "compute_ocpus" {
  type        = number
  description = "VM ammount of OCPUs"
  default     = 4
}

variable "compute_memory_in_gbs" {
  type        = number
  description = "VM ammount of RAM Memory in GB"
  default     = 16
}

variable "site_name" {
  type        = string
  description = "Name to use when registering this Access Tier with the console"
}

variable "cluster_name" {
  type        = string
  description = "Name of an existing Shield cluster to register this Access Tier with"
}

variable "refresh_token" {
  type        = string
  description = "API token generated from the Banyan console"
}

variable "site_domain_names" {
  type        = list(string)
  description = "List of aliases or CNAMEs that will direct traffic to this Access Tier"
  default     = []
}

variable "api_server" {
  type        = string
  description = "URL to the Banyan API server"
  default     = "https://net.banyanops.com/api/v1"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key to allow management access"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "ID of a custom Image to use when creating Access Tier instances (leave blank to use default)"
  default     = ""
}

variable "default_image_name" {
  type        = string
  description = "If no Image ID is supplied, use the most recent Oracle Linux 7.9 Image ID"
  default     = "Oracle-Linux-7.9-2022.+"
}

variable "min_instances" {
  type        = number
  description = "Minimum number of Access Tier instances to keep alive in the instance pool"
  default     = 2
}

variable "CPU_HIGH_TH" {
  type        = number
  description = "CPU threshold for instance pool up-scaling"
  default     = 80
}

variable "CPU_LOW_TH" {
  type        = number
  description = "CPU threshold for instance pool down-scaling"
  default     = 20
}

variable "custom_user_data" {
  type        = list(string)
  description = "Custom commands to append to the launch configuration initialization script."
  default     = []
}

variable "redirect_http_to_https" {
  type        = bool
  description = "If true, requests to the AccessTier on port 80 will be redirected to port 443"
  default     = false
}

variable "tags" {
  type        = map(any)
  description = "Add tags to each resource"
  default     = null
}

variable "network_security_group_tags" {
  type        = map
  description = "Additional tags to the network_security_group"
  default     = null
}

variable "instance_pool_tags" {
  type        = map
  description = "Additional tags to the instance pool"
  default     = null
}

variable "lb_tags" {
  type        = map
  description = "Additional tags to the lb"
  default     = null
}

variable "lb_shape" {
  type        = string
  description = "Additional tags to the lb"
  default     = "flexible"
}

variable "lb_min_bw" {
  type        = number
  description = "Minimum bandwidth in Mbps for LB"
  default     = 100
}

variable "lb_max_bw" {
  type        = number
  description = "Maximum bandwidth in Mbps for LB"
  default     = 100
}

variable "host_tags" {
  type        = map(any)
  description = "Additional tags to assign to this AccessTier"
  default     = { "type" : "access_tier" }
}

variable "groups_by_userinfo" {
  type        = bool
  description = "Derive groups information from userinfo endpoint"
  default     = false
}

variable "name_prefix" {
  type        = string
  description = "String to be added in front of all OCI object names"
  default     = "banyan"
}

variable "rate_limiting" {
  type = object({
    enabled              = bool
    max_credits          = number
    interval             = string
    credits_per_interval = number
    enable_by_key        = bool
    key_lifetime         = string
  })
  description = "Rate limiting configuration for access events"
  default = {
    enabled              = true
    max_credits          = 5000
    interval             = "1m"
    credits_per_interval = 5
    enable_by_key        = true
    key_lifetime         = "9m"
  }
}

# variable "sticky_sessions" {
#     type = bool
#     description = "Enable session stickiness for apps that require it"
#     default = false
# }