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

  nsg_rules_params = {
    ingress_443 = {
      description      = "Web traffic HTTPS"
      protocol         = "6"
      stateless        = "false"
      direction        = "INGRESS"
      source           = "0.0.0.0/0"
      source_type      = "CIDR_BLOCK"
      destination      = null
      destination_type = null
      tcp_options = [
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
    },
    ingress_80 = {
      description      = "Web traffic HTTP"
      protocol         = "6"
      stateless        = "false"
      direction        = "INGRESS"
      source           = "0.0.0.0/0"
      source_type      = "CIDR_BLOCK"
      destination      = null
      destination_type = null
      tcp_options = [
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
    },
    ingress_8443 = {
      description      = "Allow for web traffic"
      protocol         = "6"
      stateless        = "false"
      direction        = "INGRESS"
      source           = "0.0.0.0/0"
      source_type      = "CIDR_BLOCK"
      destination      = null
      destination_type = null
      tcp_options = [
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
    },
    ingress_9998 = {
      description      = "Healthcheck"
      protocol         = "6"
      stateless        = "false"
      direction        = "INGRESS"
      source           = var.healthcheck_cidr
      source_type      = "CIDR_BLOCK"
      destination      = null
      destination_type = null
      tcp_options = [
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
    },
    ingress_2222 = {
      description      = "Management"
      protocol         = "6"
      stateless        = "false"
      direction        = "INGRESS"
      source           = var.management_cidr
      source_type      = "CIDR_BLOCK"
      destination      = null
      destination_type = null
      tcp_options = [
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
    },
    egress_shield = {
      description      = "Shield (Cluster Coordinator)"
      protocol         = "6"
      stateless        = "false"
      direction        = "EGRESS"
      source           = null
      source_type      = null
      destination      = var.shield_cidr
      destination_type = "CIDR_BLOCK"
      tcp_options = [
        {
          destination_ports = [
            {
              min = var.shield_port  # shield_port defaults to 0
              max = var.shield_port != 1 ? var.shield_port : 65535
            }
          ],
          source_ports = []
        }
      ]
    },
    egress_https_cc = {
      description      = "Command Center"
      protocol         = "6"
      stateless        = "false"
      direction        = "EGRESS"
      source           = null
      source_type      = null
      destination      = var.command_center_cidr
      destination_type = "CIDR_BLOCK"
      tcp_options = [
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
    },
    egress_https_tp = {
      description      = "Command Center"
      protocol         = "6"
      stateless        = "false"
      direction        = "EGRESS"
      source           = null
      source_type      = null
      destination      = var.trustprovider_cidr
      destination_type = "CIDR_BLOCK"
      tcp_options = [
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
  }
}

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

resource "oci_core_network_security_group" "nsg" {
  display_name    = "${var.name_prefix}-accesstier-nsg"
  compartment_id  = var.compartment_id
  vcn_id          = var.vcn_id
  freeform_tags   = merge(local.tags, var.network_security_group_tags)
}

resource "oci_core_network_security_group_security_rule" "nsg_rules" {
  for_each                  = local.nsg_rules_params
  network_security_group_id = oci_core_network_security_group.nsg.id
  protocol                  = each.value.protocol
  stateless                 = each.value.stateless
  direction                 = each.value.direction
  description               = each.value.description

  source      = each.value.direction == "INGRESS" ? each.value.source : null
  source_type = each.value.direction == "INGRESS" ? each.value.source_type : null

  destination      = each.value.direction == "EGRESS" ? each.value.destination : null
  destination_type = each.value.direction == "EGRESS" ? each.value.destination_type : null
  
  dynamic "tcp_options" {
    iterator = tcp_options
    for_each = each.value.tcp_options != null ? each.value.tcp_options : []
    content {
      dynamic "destination_port_range" {
        iterator = destination_ports
        for_each = lookup(tcp_options.value, "destination_ports", null) != null ? tcp_options.value.destination_ports : []
        content {
          min = destination_ports.value.min
          max = destination_ports.value.max
        }
      }
      dynamic "source_port_range" {
        iterator = source_ports
        for_each = lookup(tcp_options.value, "source_ports", null) != null ? tcp_options.value.source_ports : []
        content {
          min = source_ports.value.min
          max = source_ports.value.max
        }
      }
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rule_internal" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  protocol                  = "all"
  stateless                 = false
  direction                 = "EGRESS"
  description               = "Managed internal services"

  destination      = var.managed_internal_cidr
  destination_type = "CIDR_BLOCK"
}

resource "oci_core_instance_pool" "ipool" {
  compartment_id            = var.compartment_id
  instance_configuration_id = oci_core_instance_configuration.conf.id
  display_name              = "${var.name_prefix}-accesstier-instance-pool"
  size                      = var.min_instances
  freeform_tags             = merge(local.ipool_tags, var.instance_pool_tags)

  dynamic placement_configurations {
  iterator = ad
  for_each = data.oci_identity_availability_domains.ads.availability_domains
  
    content {
      #Required
      availability_domain = ad.value.name
      primary_subnet_id = var.private_subnet_id
    }
  }

  load_balancers {
      backend_set_name     = oci_load_balancer_backend_set.backendset80.name
      load_balancer_id     = oci_load_balancer_load_balancer.lb.id
      port                 = 80
      vnic_selection       = "PrimaryVnic"
  }

  load_balancers {
      backend_set_name     = oci_load_balancer_backend_set.backendset443.name
      load_balancer_id     = oci_load_balancer_load_balancer.lb.id
      port                 = 443
      vnic_selection       = "PrimaryVnic"
  }

  load_balancers {
      backend_set_name     = oci_load_balancer_backend_set.backendset8443.name
      load_balancer_id     = oci_load_balancer_load_balancer.lb.id
      port                 = 8443
      vnic_selection       = "PrimaryVnic"
  }
}

resource "oci_core_instance_configuration" "conf" {
  compartment_id  = var.compartment_id
  display_name    = "${var.name_prefix}-accesstier-conf"
  


  instance_details {
    instance_type = "compute"
    

    launch_details {
      compartment_id             = var.compartment_id
      shape = var.compute_shape
    
      dynamic "shape_config" {
        for_each = local.is_flexible_node_shape ? [1] : []
        content {
          memory_in_gbs            = var.compute_memory_in_gbs
          ocpus                    = var.compute_ocpus
        }
      }

      create_vnic_details {
        nsg_ids          = tolist([oci_core_network_security_group.nsg.id])
        assign_public_ip = false
      }

      source_details {
        image_id        = var.image_id != "" ? var.image_id : data.oci_core_images.default_images.images[0].id
        source_type     = "image"
      }

      metadata = {
        ssh_authorized_keys = var.ssh_public_key
        user_data           = base64encode(join("", concat([
          "#!/bin/bash -ex\n",
          # increase file handle limits
          "echo '* soft nofile 100000' >> /etc/security/limits.d/banyan.conf\n",
          "echo '* hard nofile 100000' >> /etc/security/limits.d/banyan.conf\n",
          "echo 'fs.file-max = 100000' >> /etc/sysctl.d/90-banyan.conf\n",
          "sysctl -w fs.file-max=100000\n",
          # increase conntrack hashtable limits
          "echo 'options nf_conntrack hashsize=65536' >> /etc/modprobe.d/banyan.conf\n",
          "modprobe nf_conntrack\n",
          "echo '65536' > /proc/sys/net/netfilter/nf_conntrack_buckets\n",
          "echo '262144' > /proc/sys/net/netfilter/nf_conntrack_max\n",
          # install prerequisites and Banyan netagent
          "yum update -y\n",
          "yum install -y jq tar gzip curl sed python3\n",
          "pip3 install --upgrade pip\n",
          "/usr/local/bin/pip3 install pybanyan\n", # previous line changes /bin/pip3 to /usr/local/bin which is not in the path
          "rpm --import https://www.banyanops.com/onramp/repo/RPM-GPG-KEY-banyan\n",
          "yum-config-manager --add-repo https://www.banyanops.com/onramp/repo\n",
          "while [ -f /var/run/yum.pid ]; do sleep 1; done\n",
          "yum install -y ${var.package_name} \n",
          # configure and start netagent
          "cd /opt/banyan-packages\n",
          "BANYAN_ACCESS_TIER=true ",
          "BANYAN_REDIRECT_TO_HTTPS=${var.redirect_http_to_https} ",
          "BANYAN_SITE_NAME=${var.site_name} ",
          "BANYAN_SITE_ADDRESS=${oci_load_balancer_load_balancer.lb.ip_address_details[0].ip_address} ",
          "BANYAN_SITE_DOMAIN_NAMES=", join(",", var.site_domain_names), " ",
          "BANYAN_SITE_AUTOSCALE=true ",
          "BANYAN_API=${var.api_server} ",
          "BANYAN_HOST_TAGS=", join(",", [for k, v in var.host_tags : format("%s=%s", k, v)]), " ",
          "BANYAN_ACCESS_EVENT_CREDITS_LIMITING=${var.rate_limiting.enabled} ",
          "BANYAN_ACCESS_EVENT_CREDITS_MAX=${var.rate_limiting.max_credits} ",
          "BANYAN_ACCESS_EVENT_CREDITS_INTERVAL=${var.rate_limiting.interval} ",
          "BANYAN_ACCESS_EVENT_CREDITS_PER_INTERVAL=${var.rate_limiting.credits_per_interval} ",
          "BANYAN_ACCESS_EVENT_KEY_LIMITING=${var.rate_limiting.enable_by_key} ",
          "BANYAN_ACCESS_EVENT_KEY_EXPIRATION=${var.rate_limiting.key_lifetime} ",
          "BANYAN_GROUPS_BY_USERINFO=${var.groups_by_userinfo} ",
          "./install ${var.refresh_token} ${var.cluster_name} \n",
          "sed -i -e '/^#Port/s/^.*$/Port 2222/' /etc/ssh/sshd_config\n",
          "semanage port -a -t ssh_port_t -p tcp 2222\n",
          "/bin/systemctl restart sshd.service\n",
          "firewall-offline-cmd --zone=public --add-port=22/tcp --add-port=2222/tcp --add-port=443/tcp --add-port=8443/tcp --add-port=9998/tcp\n",
          "systemctl enable firewalld\n",
          "systemctl start firewalld\n",
          "firewall-cmd --reload"
        ], var.custom_user_data)))
      }
      freeform_tags = merge(local.ipool_tags, var.instance_pool_tags)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_load_balancer_load_balancer" "lb" {
  display_name                     = "${var.name_prefix}-lb"
  compartment_id                   = var.compartment_id
  is_private                       = false
  subnet_ids                       = tolist([var.public_subnet_id])

  shape                            = var.lb_shape
  shape_details {
    maximum_bandwidth_in_mbps = var.lb_max_bw
    minimum_bandwidth_in_mbps = var.lb_min_bw
  }

  freeform_tags = merge(local.tags, var.lb_tags)
}

resource "oci_load_balancer_backend_set" "backendset443" {
  name             = "${var.name_prefix}-backendset-443"
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  policy           = "IP_HASH"

  health_checker {
    port        = 9998
    protocol    = "HTTP"
    url_path    = "/"
    retries     = 2
    interval_ms = 3000
  }
}

resource "oci_load_balancer_listener" "listener443" {
  load_balancer_id           = oci_load_balancer_load_balancer.lb.id
  name                       = "${var.name_prefix}-listener-443"
  default_backend_set_name   = oci_load_balancer_backend_set.backendset443.name
  port                       = 443
  protocol                   = "TCP"
}

resource "oci_load_balancer_backend_set" "backendset80" {
  # count = var.redirect_http_to_https ? 1 : 0
  name             = "${var.name_prefix}-backendset-80"
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  policy           = "IP_HASH"

  health_checker {
    port        = 9998
    protocol    = "HTTP"
    url_path    = "/"
    retries     = 2
    interval_ms = 3000
  }
}

resource "oci_load_balancer_listener" "listener80" {
  # count = var.redirect_http_to_https ? 1 : 0
  load_balancer_id           = oci_load_balancer_load_balancer.lb.id
  name                       = "${var.name_prefix}-listener-80"
  default_backend_set_name   = oci_load_balancer_backend_set.backendset80.name
  port                       = 80
  protocol                   = "TCP"
}

resource "oci_load_balancer_backend_set" "backendset8443" {
  name             = "${var.name_prefix}-backendset-8443"
  load_balancer_id = oci_load_balancer_load_balancer.lb.id
  policy           = "IP_HASH"

  health_checker {
    port        = 9998
    protocol    = "HTTP"
    url_path    = "/"
    retries     = 2
    interval_ms = 3000
  }
}

resource "oci_load_balancer_listener" "listener8443" {
  load_balancer_id           = oci_load_balancer_load_balancer.lb.id
  name                       = "${var.name_prefix}-listener-8443"
  default_backend_set_name   = oci_load_balancer_backend_set.backendset8443.name
  port                       = 8443
  protocol                   = "TCP"
}

resource "oci_autoscaling_auto_scaling_configuration" "cpu_policy" {
  
  display_name           = "${var.name_prefix}-instance-pool-scaling-policy"
  compartment_id         = var.compartment_id
  
  auto_scaling_resources {
    id   = oci_core_instance_pool.ipool.id
    type = "instancePool"
  }
  
  policies {
        #Required
        policy_type = "threshold"
        display_name = format("%s-cpu-threshold", var.name_prefix)

        capacity {
            initial = var.min_instances
            max = 10
            min = var.min_instances
        }
    

        rules {
          action {
            type  = "CHANGE_COUNT_BY"
            value = "1"
          }

          display_name = format("%s-ScaleOutRule", var.name_prefix)

          metric {
            metric_type = "CPU_UTILIZATION"

            threshold {
              operator = "GT"
              value    = var.CPU_HIGH_TH
            }
          }
        }

        rules {
          action {
            type  = "CHANGE_COUNT_BY"
            value = "-1"
          }

          display_name = format("%s-ScaleInRule", var.name_prefix)

          metric {
            metric_type = "CPU_UTILIZATION"

            threshold {
              operator = "LT"
              value    = var.CPU_LOW_TH
            }
          }
        }
    }
}
