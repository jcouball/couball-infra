variable "cloudflare_api_token" {
  description = "API token for Cloudflare"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Your Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "The Zone ID of your domain"
  type        = string
}

variable "cloudflare_zone_name" {
  description = "The domain"
  type        = string
}

variable "tunnel_secret" {
  description = "Base64-encoded secret for the tunnel"
  type        = string
}

variable "proxmox_root_password" {
  description = "Password for Proxmox root user"
  type        = string
  sensitive   = true
}

variable "cloudflared_container_root_password" {
  description = "Root password for the cloudflared container"
  type        = string
  sensitive   = true
}
