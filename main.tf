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

# Kill cloud-init if it's hanging
systemctl stop cloud-init || true
systemctl mask cloud-init || true
rm -rf /var/lib/cloud/*

# Fix fstab - remove remote mounts
# sed -i '/nfs\|efs\|cifs/d' /etc/fstab
# Mount EFS (non-blocking)
mkdir -p /efs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
  fs-0985e64c096c42f09.efs.ap-south-1.amazonaws.com:/ /efs && \
  echo "EFS mounted successfully" || \
  echo "EFS mount failed (non-fatal)"

# Verify mount
df -h | grep efs || echo "EFS not mounted"

# Wait for network
for i in {1..30}; do
  ping -c1 169.254.169.254 >/dev/null 2>&1 && break
  sleep 5
done

# SSH FIRST - critical for your app
systemctl enable sshd --now
ss -tlnp | grep :22 && echo "SSHD listening" || { echo "SSHD failed"; exit 1; }

# Set multi-user (no graphical hangs)
systemctl set-default multi-user.target
systemctl isolate multi-user.target

# DCV after SSH
dnf install -y @dcvserver || echo "DCV package missing"
systemctl enable dcvserver
systemctl restart dcvserver || echo "DCV start warning"

# Tag as ready
aws ec2 create-tags \
  --region ap-south-1 \
  --resources $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  --tags Key=LabBootstrap,Value=READY

echo "========== BOOTSTRAP COMPLETE =========="




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

