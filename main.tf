provider "aws" {
  region = "ap-south-1"
}

# Importing the SG
data "aws_security_group" "TerraformSecurityGroup" {
  id = "sg-04430765f75fb1634"
}

# Generate an SSH key pair
resource "tls_private_key" "master_key_gen" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create the Key Pair
resource "aws_key_pair" "master_key_pair" {
  key_name   = "${var.name}-${var.instance_name}-${var.suffix}"
  public_key = tls_private_key.master_key_gen.public_key_openssh
}

# Windows Server instance with dynamic username and session setup
resource "aws_instance" "CentOS8-AMD" {
  ami                    = var.ami_id        # Replace with your desired CentOS AMI ID
  instance_type          = var.instance_type # Replace with your desired instance type
  key_name               = aws_key_pair.master_key_pair.key_name
  subnet_id              = "subnet-01e7e581424a68b10"
  availability_zone      = "ap-south-1a"
  vpc_security_group_ids = [data.aws_security_group.TerraformSecurityGroup.id]
  # iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  iam_instance_profile = "LabSSMRole"


  user_data = <<-EOF
#!/bin/bash
set -euo pipefail

LOG=/var/log/lab-bootstrap.log
exec > >(tee -a $LOG) 2>&1

echo "========== LAB BOOTSTRAP START =========="

# Wait for cloud-init + network (CentOS 8 specific)
cloud-init status --wait || echo "cloud-init timeout"
sleep 10
nmcli networking connectivity check || echo "Network connectivity check failed"

# Ensure SSH is ready FIRST (before DCV)
systemctl enable sshd --now
systemctl is-active --quiet sshd && echo "SSHD ready" || { echo "SSHD failed"; exit 1; }

# Install AWS CLI if missing (required for tagging)
dnf install -y awscli || echo "AWS CLI install skipped"

# DCV - wait for X11/graphical.target first
systemctl set-default graphical.target
systemctl isolate graphical.target || systemctl restart gdm
sleep 15

# Start DCV only AFTER graphical is up
systemctl enable dcvserver
systemctl restart dcvserver
systemctl is-active --quiet dcvserver && echo "DCV ready" || echo "DCV warning"

# Tag instance as ready
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION="ap-south-1"
aws ec2 create-tags \
  --region $REGION \
  --resources "$INSTANCE_ID" \
  --tags Key=LabBootstrap,Value=READY

echo "========== LAB BOOTSTRAP COMPLETE =========="


  EOF
  tags = {
    Name         = "${var.name}-${var.instance_name}-${var.suffix}"
    map-migrated = "DADS45OSDL"
    LabBootstrap = "READY"
  }
}

# Save the private key locally
resource "local_file" "local_key_pair" {
  filename        = "${var.name}-${var.instance_name}-${var.suffix}.pem"
  file_permission = "0400"
  content         = tls_private_key.master_key_gen.private_key_pem
}

# Output the CentOS8-AMD Server Public IP
output "CentOS8_AMD_Server_Public_IP" {
  value = aws_instance.CentOS8-AMD.public_ip
}

# Output Copy the URL
output "CentOS8_AMD_Login" {
  value = "Copy the mentioned URL & Paste it on Browser https://${aws_instance.CentOS8-AMD.public_ip}:8443"
}

# Output the PEM file for SSH
output "pem_file_for_ssh" {
  value     = aws_key_pair.master_key_pair.key_name
  sensitive = true
}

output "instance_id" {
  value = aws_instance.CentOS8-AMD.id
}

