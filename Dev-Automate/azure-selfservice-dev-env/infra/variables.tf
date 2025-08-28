
variable "ssh_public_key" {
  description = "Path to the SSH public key"
  type        = string
}

variable "owner_email" {
  description = "Email to receive auto-shutdown and budget alerts"
  type        = string
}
