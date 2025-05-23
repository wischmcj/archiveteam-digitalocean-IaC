variable "do_token" {}
variable "do_pvt_key" {}
variable "do_pub_key" {}
variable "warrior_username" {}
variable "warrior_password" {}
variable "warrior_project" {}
variable "warrior_concurrency" {}
variable "warrior_downloader" {}
variable "warriors_per_host" {}
variable "do_ssh_keys" {}
variable "do_hosts" {}
variable "do_observers" {}
variable "do_region" {}
variable "do_host_type" {}
variable "do_key_password" {}
variable "instance_name_prefix" {
  default = "archive-team"
}

variable "droplet_image" {
  default = "ubuntu-20-04-x64"
}