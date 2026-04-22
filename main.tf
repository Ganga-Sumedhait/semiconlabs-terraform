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

# Create AWS key pair from generated TLS key
resource "aws_key_pair" "master_key_pair" {
  key_name   = "${var.name}-${var.instance_name}-${var.suffix}"
  public_key = tls_private_key.master_key_gen.public_key_openssh
}

# Output the private key content
output "private_key_pem" {
  value     = tls_private_key.master_key_gen.private_key_pem
  sensitive = true
}

# Lab instance (Amazon Linux / DCV); bootstrap enables SSH, EFS, DCV, SSSD
resource "aws_instance" "CentOS8-AMD" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  hibernation            = true
  key_name               = aws_key_pair.master_key_pair.key_name
  subnet_id              = "subnet-01e7e581424a68b10"
  availability_zone      = "ap-south-1a"
  vpc_security_group_ids = [data.aws_security_group.TerraformSecurityGroup.id]
  iam_instance_profile   = "LabSSMRole"

  root_block_device {
    volume_size           = 40
    encrypted             = true
    delete_on_termination = true
  }


  user_data = <<-EOF

#!/bin/bash
set -euo pipefail

LOG=/var/log/lab-bootstrap.log
exec > >(tee -a $LOG) 2>&1

echo "========== LAB BOOTSTRAP START =========="

# CRITICAL: Remove EFS from fstab to prevent boot hangs
sed -i '/efs/d' /etc/fstab
sed -i '/fs-0985e64c096c42f09/d' /etc/fstab

# Wait for cloud-init
cloud-init status --wait || true

# SSH
systemctl enable sshd
systemctl restart sshd

# Mount EFS (non-blocking, will succeed now)
mkdir -p /efs
mount -t nfs4 -o nfsvers=4.1,_netdev \
  fs-0985e64c096c42f09.efs.ap-south-1.amazonaws.com:/ /efs || \
  echo "EFS mount failed (non-fatal)"

# DCV
systemctl enable dcvserver
systemctl restart dcvserver || true

# Configure NICE DCV to disable the automatic console session and use
# virtual sessions managed by the backend.
cat >/etc/dcv/dcv.conf <<'DCVCONF'
[security]
authentication="system"
pam-service-name="dcv"

[session-management]
create-session = false

[session-management/automatic-console-session]
owner = "%user%"
enable = false

[clipboard]
enable=false

[log]
log-level=debug

[connectivity]
idle-timeout=0
DCVCONF

systemctl restart dcvserver || true

# Best-effort: close default console session so virtual sessions are not blocked by max-session limit
sleep 2
sudo dcv close-session console 2>/dev/null || true

# DCV logout watcher is NOT installed here: bake it into your golden lab AMI once
# (see golden-ami-dcv-watcher.sh in this repo), then set var.ami_id to that AMI.

# SSSD
systemctl enable sssd
systemctl restart sssd || true

# Tag as ready
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags \
  --region ap-south-1 \
  --resources "$INSTANCE_ID" \
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

# Output the PEM file for SSH (now using generated keypair name)
output "pem_file_for_ssh" {
  value     = aws_key_pair.master_key_pair.key_name
  sensitive = true
}

output "instance_id" {
  value = aws_instance.CentOS8-AMD.id
}

