locals {

  compute_flexible_shapes = [
    "VM.Standard.E3.Flex",
    "VM.Standard.E4.Flex",
    "VM.Standard.A1.Flex"
  ]

  is_flexible_node_shape = contains(local.compute_flexible_shapes, var.compute_shape)

  tags = merge(var.tags, {
    Provider = "BanyanOps"
  })

  ipool_tags = merge(local.tags, {
    Name = "${var.site_name}-BanyanHost"
  })

  ingress_80 = {
        for cidr in ["0.0.0.0/0"]:
            format("ingress_%s_80", cidr) => {
                description      = "Redirect to 443"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 80
                        max = 80
                        }
                    ],
                    source_ports = []
                    }
                ]
            }
  }

  base_hosts_nsg_rules_params = merge(
    {
        for cidr in ["0.0.0.0/0"]:
            format("ingress_%s_443", cidr) => {
                description      = "Web traffic"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 443
                        max = 443
                        }
                    ],
                    source_ports = []
                    }
                ]
            }
    },
    {
        for cidr in ["0.0.0.0/0"]:
            format("ingress_%s_8443", cidr) => {
                description      = "Allow for web traffic"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 8443
                        max = 8443
                        }
                    ],
                    source_ports = []
                    }
                ]
            }
    },
    {
        for cidr in var.healthcheck_cidrs:
            format("ingress_%s_9998", cidr) => {
                description      = "Healthcheck"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 9998
                        max = 9998
                        }
                    ],
                    source_ports = []
                    }
                ]
            }

    },
    {
        for cidr in var.management_cidrs:
            format("ingress_%s_2222", cidr) => {
                description      = "Management"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 2222
                        max = 2222
                        }
                    ],
                    source_ports = []
                    }
                ]
            }

    },
    {
        for cidr in var.shield_cidrs:
            format("egress_shield_%s", cidr) => {
                description      = "Shield (Cluster Coordinator)"
                protocol         = "6"
                stateless        = "false"
                direction        = "EGRESS"
                source           = null
                destination      = cidr
                tcp_options      = [
                    {
                    destination_ports = var.shield_port == 0 ? [] : [
                        {
                        min = var.shield_port
                        max = var.shield_port
                        }
                    ],
                    source_ports = []
                    }
                ]
            }

    },
    {
        for cidr in var.command_center_cidrs:
            format("command_center_%s", cidr) => {
                description      = "Command Center"
                protocol         = "6"
                stateless        = "false"
                direction        = "EGRESS"
                source           = null
                destination      = cidr
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 443
                        max = 443
                        }
                    ],
                    source_ports = []
                    }
                ]
            }

    },
    {
        for cidr in var.trustprovider_cidrs:
            format("trust_provider_%s", cidr) => {
                description      = "TrustProvider"
                protocol         = "6"
                stateless        = "false"
                direction        = "EGRESS"
                source           = null
                destination      = cidr
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 443
                        max = 443
                        }
                    ],
                    source_ports = []
                    }
                ]
            }

    },
    {
        for cidr in var.managed_internal_cidrs:
            format("managed_internal_%s", cidr) => {
                description      = "TrustProvider"
                protocol         = "all"
                stateless        = "false"
                direction        = "EGRESS"
                source           = null
                destination      = cidr
                tcp_options      = []
            }

    }
  )

  base_nlb_nsg_rules_params = merge(
    {
        for cidr in ["0.0.0.0/0"]:
            format("ingress_%s_443", cidr) => {
                description      = "Web traffic"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 443
                        max = 443
                        }
                    ],
                    source_ports = []
                    }
                ]
            }
    },
    {
        for cidr in ["0.0.0.0/0"]:
            format("ingress_%s_8443", cidr) => {
                description      = "Allow for web traffic"
                protocol         = "6"
                stateless        = "false"
                direction        = "INGRESS"
                source           = cidr
                destination      = null
                tcp_options      = [
                    {
                    destination_ports = [
                        {
                        min = 8443
                        max = 8443
                        }
                    ],
                    source_ports = []
                    }
                ]
            }
    }
  )
  
  hosts_nsg_rules_params = var.redirect_http_to_https ? merge(local.base_hosts_nsg_rules_params, local.ingress_80) : local.base_hosts_nsg_rules_params
  nlb_nsg_rules_params = var.redirect_http_to_https ? merge(local.base_nlb_nsg_rules_params, local.ingress_80) : local.base_hosts_nsg_rules_params

}
