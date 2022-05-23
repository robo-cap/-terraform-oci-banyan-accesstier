resource "oci_core_network_security_group" "nsg_hosts" {
  display_name    = "${var.name_prefix}-accesstier-hosts-nsg"
  compartment_id  = var.compartment_id
  vcn_id          = var.vcn_id
  freeform_tags   = merge(local.tags, var.network_security_group_tags)
}

resource "oci_core_network_security_group" "nsg_nlb" {
  display_name    = "${var.name_prefix}-accesstier-nlb-nsg"
  compartment_id  = var.compartment_id
  vcn_id          = var.vcn_id
  freeform_tags   = merge(local.tags, var.network_security_group_tags)
}


resource "oci_core_network_security_group_security_rule" "nsg_hosts_rules" {
  for_each                  = local.hosts_nsg_rules_params
  network_security_group_id = oci_core_network_security_group.nsg_hosts.id
  protocol                  = each.value.protocol
  stateless                 = each.value.stateless
  direction                 = each.value.direction
  description               = each.value.description

  source      = each.value.direction == "INGRESS" ? each.value.source : null
  source_type = each.value.direction == "INGRESS" ? "CIDR_BLOCK" : null

  destination      = each.value.direction == "EGRESS" ? each.value.destination : null
  destination_type = each.value.direction == "EGRESS" ? "CIDR_BLOCK" : null
  
  dynamic "tcp_options" {
    iterator = tcp_options
    for_each = each.value.tcp_options != [] ? each.value.tcp_options : []
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

resource "oci_core_network_security_group_security_rule" "nsg_nlb_rules" {
  for_each                  = local.nlb_nsg_rules_params
  network_security_group_id = oci_core_network_security_group.nsg_nlb.id
  protocol                  = each.value.protocol
  stateless                 = each.value.stateless
  direction                 = each.value.direction
  description               = each.value.description

  source      = each.value.direction == "INGRESS" ? each.value.source : null
  source_type = each.value.direction == "INGRESS" ? "CIDR_BLOCK" : null

  destination      = each.value.direction == "EGRESS" ? each.value.destination : null
  destination_type = each.value.direction == "EGRESS" ? "CIDR_BLOCK" : null
  
  dynamic "tcp_options" {
    iterator = tcp_options
    for_each = each.value.tcp_options != [] ? each.value.tcp_options : []
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

resource "oci_core_instance_pool" "ipool" {
  compartment_id            = var.compartment_id
  instance_configuration_id = oci_core_instance_configuration.conf.id
  display_name              = "${var.name_prefix}-accesstier-instance-pool"
  size                      = var.min_instances
  freeform_tags             = merge(local.ipool_tags, var.instance_pool_tags)

  dynamic "placement_configurations" {
    iterator = ad
    for_each = data.oci_identity_availability_domains.ads.availability_domains
      content {
        availability_domain = ad.value.name
        primary_subnet_id = var.private_subnet_id
      }
  }

  dynamic "load_balancers" {
    for_each = var.redirect_http_to_https ? [true] : []
    content {
      backend_set_name     = oci_network_load_balancer_backend_set.backendset80.name
      load_balancer_id     = oci_network_load_balancer_network_load_balancer.nlb.id
      port                 = 80
      vnic_selection       = "PrimaryVnic"
    }
  }

  load_balancers {
      backend_set_name     = oci_network_load_balancer_backend_set.backendset443.name
      load_balancer_id     = oci_network_load_balancer_network_load_balancer.nlb.id
      port                 = 443
      vnic_selection       = "PrimaryVnic"
  }

  load_balancers {
      backend_set_name     = oci_network_load_balancer_backend_set.backendset8443.name
      load_balancer_id     = oci_network_load_balancer_network_load_balancer.nlb.id
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
        for_each = local.is_flexible_node_shape ? [true] : []
        content {
          memory_in_gbs            = var.compute_memory_in_gbs
          ocpus                    = var.compute_ocpus
        }
      }

      create_vnic_details {
        nsg_ids          = tolist([oci_core_network_security_group.nsg_hosts.id])
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
          "yum install -y jq tar gzip curl sed python3 policycoreutils-python-utils\n",
          "pip3 install --upgrade pip\n",
          "/usr/local/bin/pip3 install pybanyan\n", # previous line changes /bin/pip3 to /usr/local/bin which is not in the path
          var.datadog_api_key != "" ? "curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh | DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=${var.datadog_api_key} DD_SITE=${var.datadog_site} bash -v\n" : "",
          "for i in 1 2 3 4 5; do rpm --import https://www.banyanops.com/onramp/repo/RPM-GPG-KEY-banyan && break || sleep 15; done\n",
          "yum-config-manager --add-repo https://www.banyanops.com/onramp/repo\n",
          "while [ -f /var/run/yum.pid ]; do sleep 1; done\n",
          "yum install -y ${var.package_name}\n",
          # configure and start netagent
          "cd /opt/banyan-packages\n",
          "BANYAN_ACCESS_TIER=true ",
          "BANYAN_REDIRECT_TO_HTTPS=${var.redirect_http_to_https} ",
          "BANYAN_SITE_NAME=${var.site_name} ",
          "BANYAN_SITE_ADDRESS=${oci_network_load_balancer_network_load_balancer.nlb.ip_addresses[0].ip_address} ",
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
          var.datadog_api_key != "" ? "BANYAN_STATSD=true BANYAN_STATSD_ADDRESS=127.0.0.1:8125 " : "",
          "./install ${var.refresh_token} ${var.cluster_name}\n",
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

resource "oci_network_load_balancer_network_load_balancer" "nlb" {
  display_name                   = "${var.name_prefix}-nlb"
  compartment_id                 = var.compartment_id
  subnet_id                      = var.public_subnet_id
  is_private                     = false
  is_preserve_source_destination = true
  network_security_group_ids     = tolist([oci_core_network_security_group.nsg_nlb.id])
  freeform_tags                  = merge(local.tags, var.nlb_tags)
}

resource "oci_network_load_balancer_backend_set" "backendset443" {
  name                      = "${var.name_prefix}-backendset-443"
  network_load_balancer_id  = oci_network_load_balancer_network_load_balancer.nlb.id
  policy                    = "FIVE_TUPLE"

  health_checker {
    port                = 9998
    protocol            = "HTTP"
    return_code         = 200
    url_path            = "/"
    retries             = 2
    interval_in_millis  = 30000
  }
}

resource "oci_network_load_balancer_listener" "listener443" {
  network_load_balancer_id   = oci_network_load_balancer_network_load_balancer.nlb.id
  name                       = "${var.name_prefix}-listener-443"
  default_backend_set_name   = oci_network_load_balancer_backend_set.backendset443.name
  port                       = 443
  protocol                   = "TCP"
}

resource "oci_network_load_balancer_backend_set" "backendset80" {
  count                    = var.redirect_http_to_https ? 1 : 0
  name                     = "${var.name_prefix}-backendset-80"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.nlb.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    port                = 9998
    protocol            = "HTTP"
    return_code         = 200
    url_path            = "/"
    retries             = 2
    interval_in_millis  = 30000
  }
}

resource "oci_network_load_balancer_listener" "listener80" {
  count                      = var.redirect_http_to_https ? 1 : 0
  network_load_balancer_id   = oci_network_load_balancer_network_load_balancer.nlb.id
  name                       = "${var.name_prefix}-listener-80"
  default_backend_set_name   = oci_network_load_balancer_backend_set.backendset80[count.index].name
  port                       = 80
  protocol                   = "TCP"
}

resource "oci_network_load_balancer_backend_set" "backendset8443" {
  name                     = "${var.name_prefix}-backendset-8443"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.nlb.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    port                = 9998
    protocol            = "HTTP"
    return_code         = 200
    url_path            = "/"
    retries             = 2
    interval_in_millis  = 30000
  }
}

resource "oci_network_load_balancer_listener" "listener8443" {
  network_load_balancer_id   = oci_network_load_balancer_network_load_balancer.nlb.id
  name                       = "${var.name_prefix}-listener-8443"
  default_backend_set_name   = oci_network_load_balancer_backend_set.backendset8443.name
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
