
output "ips" {
  value = "${jsonencode(digitalocean_droplet.prometheus.*.ipv4_address[0])}"
}

output "prometheus_ip" {
  value = "${digitalocean_droplet.prometheus.*.ipv4_address}"
}

output "urls" {
  value ={ for drop in digitalocean_droplet.prometheus:
             "Prometheus" => "https://${drop.ipv4_address}:9090"}
}

output "ansible_cmds" {
  value ={ for drop in digitalocean_droplet.prometheus:
             "Prometheus" => "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i '${drop.ipv4_address},' --private-key ${var.do_pvt_key} -e 'pub_key=${var.do_pub_key}' ansible/playbooks/apt_docker.yml"
          }
}

# data "local_file" "prometheus_file" {
#   filename = "metrics/prometheus.yml"
#   content = templatefile("metrics/prometheus.yml",
#     {
#       nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
#     })
#  }
 
# output "prometheus_file" {
#   value = data.local_file.prometheus_file
#  }

# output "prometheus_file" {
#   value = tostring(templatefile("metrics/prometheus.yml",
#     {
#       nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
#     }))
#  }
 
# output "metrics_js" {
#   value = tostring(
#     templatefile("metrics/metrics.js",
#       {
#         nodes = "${jsonencode(digitalocean_droplet.archiveteam.*.ipv4_address)}"
#         ports = "${var.warriors_per_host}"
#         username = "${var.warrior_username}"
#         password = "${var.warrior_password}"
#       })
#       )
# }

# output "start" {
#   value = tostring(
#     templatefile("start.sh",
#     {
#       warriors = "${var.warriors_per_host}"
#     }))
# }
