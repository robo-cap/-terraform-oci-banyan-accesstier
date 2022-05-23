output "lb_ip_address" {
  value       = oci_network_load_balancer_network_load_balancer.nlb.ip_addresses[0].ip_address
  description = "Public IP address of the load balancer"
}

output "network_security_group_id" {
  value       = oci_core_network_security_group.nsg.id
  description = "The ID of the network security group, which can be added as an inbound rule on other backend groups"
}

output "sg" {
  value       = oci_core_network_security_group.nsg
  description = "The `oci_core_network_security_group.nsg` resource" 
}

output "instance_pool" {
  value       = oci_core_instance_pool.ipool
  description = "The `oci_core_instance_pool.ipool` resource" 
}

output "nlb" {
  value       = oci_network_load_balancer_network_load_balancer.nlb
  description = "The `oci_network_load_balancer_network_load_balancer.nlb` resource" 
}

output "backendset443" {
  value       = oci_network_load_balancer_backend_set.backendset443
  description = "The `oci_network_load_balancer_backend_set.backendset443` resource" 
}

output "backendset8443" {
  value       = oci_network_load_balancer_backend_set.backendset8443
  description = "The `oci_network_load_balancer_backend_set.backendset8443` resource" 
}

output "backendset80" {
  value       = var.redirect_http_to_https ? oci_network_load_balancer_backend_set.backendset80[0] : {}
  description = "The `oci_network_load_balancer_backend_set.backendset80` resource" 
}

output "listener443" {
  value       = oci_network_load_balancer_listener.listener443
  description = "The `oci_network_load_balancer_listener.listener443` resource" 
}

output "listener8443" {
  value       = oci_network_load_balancer_listener.listener8443
  description = "The `oci_network_load_balancer_listener.listener8443` resource" 
}

output "listener80" {
  value       = var.redirect_http_to_https ? oci_network_load_balancer_listener.listener80[0] : {}
  description = "The `oci_network_load_balancer_listener.listener80` resource" 
}

output "cpu_policy" {
  value       = oci_autoscaling_auto_scaling_configuration.cpu_policy
  description = "The `oci_autoscaling_auto_scaling_configuration.cpu_policy` resource" 
}
