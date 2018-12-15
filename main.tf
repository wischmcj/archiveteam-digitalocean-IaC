variable "do_token" {}
variable "warrior_username" {}
variable "warrior_password" {}
variable "warrior_project" {}
variable "warrior_concurrency" {}
variable "warrior_downloader" {}
variable "warriors_per_host" {}
variable "do_ssh_keys" {}
variable "do_hosts" {}
variable "do_region" {}
variable "do_host_type" {}

variable "instance_name_prefix" {
  default = "archive-team"
}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_droplet" "prometheus" {
  image  = "ubuntu-18-04-x64"
  name   = "${var.instance_name_prefix}-prometheus"
  region = "${var.do_region}"
  size   = "s-1vcpu-2gb"
  count  = 1
  ssh_keys = "${split(",", var.do_ssh_keys)}"
}

resource "null_resource" "deps" {
  count = 1
  triggers = {
    ids = "${join(",", digitalocean_droplet.prometheus.*.id)}"
  }

  connection {
    host = "${element(digitalocean_droplet.prometheus.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sSL https://get.docker.com/ | sh",
      "curl -sSL https://agent.digitalocean.com/install.sh | sh",
    ]
  }
}

data "template_file" "prom_nodes" {
  template = "${file("metrics/prometheus.yml")}"

  vars {
    nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
  }
}

data "template_file" "warrior_env" {
  template = "${file("env")}"

  vars {
    downloader = "${var.warrior_downloader}"
    project = "${var.warrior_project}"
    username = "${var.warrior_username}"
    password = "${var.warrior_password}"
    concurrency = "${var.warrior_concurrency}"
  }
}

data "template_file" "warrior_start_script" {
  template = "${file("start.sh")}"

  vars {
    warriors = "${var.warriors_per_host}"
  }
}

data "template_file" "metrics_nodes" {
  template = "${file("metrics/metrics.js")}"

  vars {
    nodes = "${jsonencode(digitalocean_droplet.archiveteam.*.ipv4_address)}"
    ports = "${var.warriors_per_host}"
    username = "${var.warrior_username}"
    password = "${var.warrior_password}"
  }
}

resource "null_resource" "prometheus" {
  count = 1
  triggers = {
    ids = "${join(",", digitalocean_droplet.prometheus.*.id)}"
    prometheus = "${sha1(file("metrics/prometheus.yml"))}"
    nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
  }

  depends_on = ["null_resource.deps"]

  connection {
    host = "${element(digitalocean_droplet.prometheus.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /prometheus || true",
      "chmod -R 777 /prometheus || true",
      "docker stop prometheus && docker rm prometheus || true",
    ]
  }

  provisioner "file" {
    content = "${data.template_file.prom_nodes.rendered}"
    destination = "/prometheus.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker run -d --name prometheus --restart=always --net=host -v /prometheus.yml:/etc/prometheus/prometheus.yml -v /prometheus:/prometheus prom/prometheus"
    ]
  }
}

resource "null_resource" "ws_metrics" {
  count = 1
  triggers = {
    ids = "${join(",", digitalocean_droplet.prometheus.*.id)}"
    metrics_script = "${sha1(file("metrics/metrics.js"))}"
    nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
    warriors = "${var.warriors_per_host}"
  }

  depends_on = [
    "null_resource.prometheus",
    "null_resource.warrior"
  ]

  connection {
    host = "${element(digitalocean_droplet.prometheus.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /metrics || true",
    ]
  }

  provisioner "file" {
    content = "${data.template_file.metrics_nodes.rendered}"
    destination = "/metrics/metrics.js"
  }

  provisioner "file" {
    source = "metrics/package.json"
    destination = "/metrics/package.json"
  }

  provisioner "remote-exec" {
    inline = [
      "docker stop metrics && docker rm metrics || true",
      "docker run -d --restart=always --net=host --name metrics -v /metrics:/usr/src/app -w /usr/src/app node:8 bash -c 'npm install && node metrics.js'",
    ]
  }
}

resource "digitalocean_droplet" "archiveteam" {
  image  = "ubuntu-18-04-x64"
  name   = "${var.instance_name_prefix}-warrior-${count.index}"
  region = "${var.do_region}"
  size   = "${var.do_host_type}"
  count  = "${var.do_hosts}"
  ssh_keys = "${split(",", var.do_ssh_keys)}"
}

resource "null_resource" "docker" {
  count  = "${var.do_hosts}"

  triggers = {
    host = "${digitalocean_droplet.archiveteam.*.id[count.index]}"
  }

  connection {
    host = "${element(digitalocean_droplet.archiveteam.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sSL https://get.docker.com/ | sh || true",
      "curl -sSL https://agent.digitalocean.com/install.sh | sh",
    ]
  }
}

resource "null_resource" "warrior" {
  count  = "${var.do_hosts}"
  depends_on = ["null_resource.docker"]

  triggers = {
    host = "${digitalocean_droplet.archiveteam.*.id[count.index]}"
    start_file = "${sha1(data.template_file.warrior_start_script.rendered)}"
    env = "${sha1(data.template_file.warrior_env.rendered)}"
    warriors = "${var.warriors_per_host}"
  }

  connection {
    host = "${element(digitalocean_droplet.archiveteam.*.ipv4_address, count.index)}"
  }

  provisioner "file" {
    content = "${data.template_file.warrior_env.rendered}"
    destination = "/tmp/env"
  }

  provisioner "file" {
    content = "${data.template_file.warrior_start_script.rendered}"
    destination = "/tmp/start.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "docker stop exporter && docker rm exporter || true",
      "docker run -d --name exporter --net=host --pid=host -v '/:/host:ro,rslave' quay.io/prometheus/node-exporter --path.rootfs /host",
      "chmod +x /tmp/start.sh",
      "/tmp/start.sh",
    ]
  }
}

output "ips" {
  value = "${digitalocean_droplet.archiveteam.*.ipv4_address}"
}

output "prometheus" {
  value = "${digitalocean_droplet.prometheus.ipv4_address}"
}
