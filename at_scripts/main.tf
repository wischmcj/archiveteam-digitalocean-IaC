
# Provision 2 categories of droplets
## Prometheus nodes - run prometheus
## Archiveteam - runs one to many instances of warriors

resource "digitalocean_droplet" "prometheus" {
  image  = "${var.droplet_image}"
  name   = "${var.instance_name_prefix}-prometheus"
  region = "${var.do_region}"
  size   = "s-1vcpu-2gb"
  count  = 1
  # ssh_keys = "${split(",", var.do_ssh_keys)}"
  # ssh_keys = [data.digitalocean_ssh_key.example.id]
  ssh_keys = [
    data.digitalocean_ssh_key.example.id
  ]
  provisioner "remote-exec" {
    # needed to ensure that drop is available before local-exec
    connection {
      host = self.ipv4_address
      user = "root"
      type = "ssh"
      private_key = file(var.do_pvt_key)
      timeout = "1m"
    }
    inline = [
      "mkdir /prometheus || true",
      "chmod -R 777 /prometheus || true"
    ]
  }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i '${self.ipv4_address},' --private-key ${var.do_pvt_key} -e 'pub_key=${var.do_pub_key}' ansible/playbooks/apt_docker.yml"
  }
}

output "droplet_ip_addresses" {
  value = {
    for droplet in digitalocean_droplet.prometheus:
    droplet.name => droplet.ipv4_address
  }
}



resource "digitalocean_droplet" "archiveteam" {
  image  = "${var.droplet_image}"
  name   = "${var.instance_name_prefix}-warrior"
  region = "${var.do_region}"
  size   = "${var.do_host_type}"
  count  =  1
  # ssh_keys = "${split(",", var.do_ssh_keys)}"
  ssh_keys = [
    data.digitalocean_ssh_key.example.id
  ]
  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = file(var.do_pvt_key)
    timeout = "1m"
  }
  provisioner "remote-exec" {
    # needed to ensure that drop is available before local-exec
    connection {
      host = self.ipv4_address
      user = "root"
      type = "ssh"
      private_key = file(var.do_pvt_key)
      timeout = "1m"
    }
    inline = [
      "echo 'test'"
      # "docker stop exporter && docker rm exporter || true",
      # "docker run -d --name exporter --net=host --pid=host -v '/:/host:ro,rslave'  prom/node-exporter --path.rootfs /host",
      # "chmod +x /tmp/start.sh",
      # "/tmp/start.sh",
    ]
  }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i '${self.ipv4_address},' --private-key ${var.do_pvt_key} -e 'pub_key=${var.do_pub_key}' ansible/playbooks/apt_docker.yml"
  }
}
# setting up file system volume for and 
# starting the docker image for prometheus on the prometheus node 

resource "null_resource" "prometheus" {
  count = 1
  triggers = {
    ids = "${join(",", digitalocean_droplet.prometheus.*.id)}"
    prometheus = "${sha1(file("metrics/prometheus.yml"))}"
    nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
  }
  depends_on = [digitalocean_droplet.prometheus ]

  # connection {
  #   host = "${element(digitalocean_droplet.prometheus.*.ipv4_address, count.index)}"
  # }

  connection {
    host ="${element(digitalocean_droplet.prometheus.*.ipv4_address, count.index)}"
    user = "root"
    type = "ssh"
    private_key = file(var.do_pvt_key)
    timeout = "1m"
  }
  
  provisioner "remote-exec" {
    # command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i '${self.ipv4_address}' --private-key ${var.do_pvt_key} -e 'pub_key=${var.do_pub_key}' ansible/playbooks/apt_docker.yml"
 
    inline = [
      "docker stop prometheus && docker rm prometheus || true",
    ]
  }

  provisioner "file" {
    content = templatefile("metrics/prometheus.yml",
    {
      nodes = "${jsonencode(formatlist("%s:9100", digitalocean_droplet.archiveteam.*.ipv4_address))}"
    })
    # content =  module.template_files.files.prom_nodes
    destination = "/prometheus.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker run -d --name prometheus --restart=always --net=host -v /prometheus.yml:/etc/prometheus/prometheus.yml -v /prometheus:/prometheus prom/prometheus"
    ]
  }
}

resource "null_resource" "warrior" {
  count  = "${var.do_hosts}"
  depends_on = [digitalocean_droplet.archiveteam]

  triggers = {
    host = "${digitalocean_droplet.archiveteam.*.id[count.index]}"
    start_file = templatefile("start.sh",
    {
      nodes = "${var.warriors_per_host}"
    })
    env = templatefile("env",
      {
        downloader = "${var.warrior_downloader}"
        project = "${var.warrior_project}"
        username = "${var.warrior_username}"
        password = "${var.warrior_password}"
        concurrency = "${var.warrior_concurrency}"
      })
      
    warriors = "${var.warriors_per_host}"
  }
  
  
  connection {
    host = "${digitalocean_droplet.archiveteam.*.ipv4_address[count.index]}"
    user = "root"
    type = "ssh"
    private_key = file(var.do_pvt_key)
    timeout = "1m"
  }
  # connection {
  #   host = "${element(digitalocean_droplet.archiveteam.*.ipv4_address,0)}"
  # }

  provisioner "file" {
    content = templatefile("env",
    {
        downloader = "${var.warrior_downloader}"
        project = "${var.warrior_project}"
        username = "${var.warrior_username}"
        password = "${var.warrior_password}"
        concurrency = "${var.warrior_concurrency}"
    })
    destination = "/tmp/env"
  }

  provisioner "file" {
    content = templatefile("start.sh",
    {
      warriors = "${var.warriors_per_host}"
    })
    destination = "/tmp/start.sh"
  }

  provisioner "remote-exec" {
    # Stops container named exporter if running 
    # Starts instance of node-exporter, which monitors 
    #  the warrior container, returning metrics to prometheus
    inline = [
      # "docker stop exporter && docker rm exporter || true",
      "docker run -d --name exporter 
      --net=host --pid=host -v '/:/host:ro,rslave' 
       prom/node-exporter --path.rootfs /host",
      "chmod +x /tmp/start.sh",
      "/tmp/start.sh",
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
    warrior_concurrency = "${var.warrior_concurrency}"
  }

  depends_on = [
    null_resource.prometheus,
    null_resource.warrior
  ]

  connection {
    host = "${element(digitalocean_droplet.prometheus.*.ipv4_address, count.index)}"
    user = "root"
    type = "ssh"
    private_key = file(var.do_pvt_key)
    timeout = "1m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /metrics || true",
    ]
  }

  provisioner "file" {
    content = templatefile("metrics/metrics.js",
      {
        nodes = "${jsonencode(digitalocean_droplet.archiveteam.*.ipv4_address)}"
        ports = "${var.warriors_per_host}"
        username = "${var.warrior_username}"
        password = "${var.warrior_password}"
      })
    # content = module.template_files.files.metrics
    destination = "/metrics/metrics.js"
  }
  // loads dependency list to droplet
  provisioner "file" {
    source = "metrics/package.json"
    destination = "/metrics/package.json"
  }

  provisioner "remote-exec" {
    inline = [
      "docker stop metrics && docker rm metrics || true",
      "docker run -d --restart=always --net=host
       --name metrics -v /metrics:/usr/src/app 
       -w /usr/src/app node:8 bash -c 'npm install && node metrics.js'",
    ]
  }
}