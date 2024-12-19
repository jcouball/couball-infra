terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.1-rc4"
    }
  }
  required_version = ">= 1.0"
}

# Define the Cloudflare Tunnel

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "couball_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "couball_tunnel"
  secret     = var.tunnel_secret # Base64-encoded secret
  config_src = "local"
}

resource "cloudflare_record" "hello_world" {
  zone_id         = var.cloudflare_zone_id
  name            = var.hello_world_domain
  type            = "CNAME"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.couball_tunnel.id}.cfargotunnel.com"
  proxied         = true
  allow_overwrite = true
}

provider "proxmox" {
  pm_api_url      = "https://${var.proxmox_ip}:8006/api2/json"
  pm_user         = "root@pam"
  pm_password     = var.proxmox_root_password
  pm_tls_insecure = true
}

resource "proxmox_lxc" "cloudflared_container" {
  target_node  = "proxmox-01"
  vmid         = 101
  hostname     = "cloudflared"
  password     = var.cloudflared_container_root_password # Variable for container root password
  ostemplate   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"

  features {
    nesting = true
  }

  rootfs {
    storage = "local-lvm"
    size    = "8G"
  }

  cores        = 1
  memory       = 128
  swap         = 128

  ssh_public_keys = file("~/.ssh/id_rsa_cloudflared_admin.pub")

  network {
    name   = "eth0"
    hwaddr = "02:00:C0:A8:02:65"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  start = true

  lifecycle {
    ignore_changes = [network]
  }
}

data "external" "get_cloudflared_ip" {
  program = ["bash", "${path.module}/get_ip", var.proxmox_ip, proxmox_lxc.cloudflared_container.vmid]

  depends_on = [
    proxmox_lxc.cloudflared_container
  ]
}

output "cloudflared_ip" {
  value       = data.external.get_cloudflared_ip.result.ip
  description = "The dynamic IP address of the cloudflared container assigned via DHCP"
}

locals {
  cloudflared_script = templatefile("${path.module}/cloudflared-config.sh", {
    account_id                   = var.cloudflare_account_id
    tunnel_id                    = cloudflare_zero_trust_tunnel_cloudflared.couball_tunnel.id
    tunnel_name                  = cloudflare_zero_trust_tunnel_cloudflared.couball_tunnel.name
    tunnel_secret                = var.tunnel_secret
    hello_world_domain           = var.hello_world_domain
    hello_world_internal_address = "http://192.168.2.102:8080"
  })
}

resource "null_resource" "run_cloudflared_config_script" {
  depends_on = [data.external.get_cloudflared_ip]

  triggers = {
    script_checksum = filesha256("${path.module}/cloudflared-config.sh")
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = data.external.get_cloudflared_ip.result.ip
      user        = "root"
      private_key = file("~/.ssh/id_rsa_cloudflared_admin")
    }

    inline = [
      "${local.cloudflared_script}"
    ]
  }
}
