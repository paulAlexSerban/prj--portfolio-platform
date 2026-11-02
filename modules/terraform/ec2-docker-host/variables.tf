variable "name" {
  description = "Short name used for the instance, security group, and IAM role. Lowercase letters, digits, and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.name))
    error_message = "name must be 3 to 40 characters: lowercase letters, digits, and hyphens."
  }
}

variable "instance_type" {
  description = "EC2 instance type. t4g.small (2 GB) is the smallest size that comfortably runs WordPress and MariaDB together. t4g.micro needs the swap file this module creates and is still tight."
  type        = string
  default     = "t4g.small"
}

variable "volume_size_gb" {
  description = "Encrypted gp3 root volume size in GB. Holds the OS, Docker images, the database volume, and uploads."
  type        = number
  default     = 20

  validation {
    condition     = var.volume_size_gb >= 20 && var.volume_size_gb <= 100
    error_message = "volume_size_gb must be between 20 and 100."
  }
}

variable "vpc_id" {
  description = "VPC for the security group. Null uses the region's default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Public subnet for the instance. Null uses a default subnet of the default VPC. Set together with vpc_id."
  type        = string
  default     = null

  validation {
    condition     = (var.subnet_id == null) == (var.vpc_id == null)
    error_message = "Set vpc_id and subnet_id together, or leave both empty to use the default VPC."
  }
}

variable "extra_user_data" {
  description = "Shell appended to user_data after Docker, the compose plugin, and the 1 GB swap file are installed. Runs as root on first boot."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to resources this module creates."
  type        = map(string)
  default     = {}
}
