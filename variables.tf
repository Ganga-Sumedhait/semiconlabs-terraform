variable "keypair_name" {
  description = "EC2's Key Pair"
  type    = string
  # default = "Koushal-Manual_Server"
}

# Instance name for tagging the Windows server
variable "instance_name" {
  description = "EC2 Instance Server Name"
  type        = string
  # default = "DCVTestInstance"
}

variable "ami_id" {
  description = "ami image"
  type = string
  # default = "ami-0fc2776da09fb303e"
}

variable "name" {
  # Used for Prefix
  description = "Name tag for the Instance"
  type        = string
  default     = "Sumedha-CloudLabs_Server"
}

variable "instance_type" {
  description = "Instance Type for EC2"
  type        = string
  # default = "t3a.medium"
}

variable "suffix" {
  description = "Suffix for the variables"
  type        = string
  # default = "Koushal-Manual_"
}
