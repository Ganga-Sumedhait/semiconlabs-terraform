# keypair_name variable removed - now using Terraform-generated keypair
# variable "keypair_name" {
#   description = "EC2's Key Pair"
#   type        = string
#   # default = "Koushal-Manual_Server"
# }

# Instance name for tagging the Windows server
variable "instance_name" {
  description = "EC2 Instance Server Name"
  type        = string
  # default = "DCVTestInstance"
}

variable "ami_id" {
  description = "ami image"
  type        = string
  default     = "ami-09de70deff4a6e379"
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

# key_name variable removed - now using Terraform-generated keypair
# variable "key_name" {
#   description = "Existing EC2 keypair name"
#   type        = string
# }

variable "suffix" {
  description = "Suffix for the variables"
  type        = string
  # default = "Koushal-Manual_"
}

#resource "aws_iam_instance_profile" "ssm_profile" {
#  name = "ssm-profile"
#  role = "AmazonSSMManagedInstanceCore"
#}

# resource "aws_iam_role" "ssm_role" {
#   name = "LabSSMRole"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ssm_attach" {
#   role       = aws_iam_role.ssm_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_instance_profile" "ssm_profile" {
#   name = "LabSSMProfile"
#   role = aws_iam_role.ssm_role.name
# }

