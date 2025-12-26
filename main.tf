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
    set -e

    LOG=/var/log/lab-bootstrap.log
    exec > >(tee -a $LOG) 2>&1

    echo "========== LAB BOOTSTRAP START =========="

    sleep 30

    echo "[1/6] Restarting critical services"
    systemctl restart sssd || true
    systemctl restart dcvserver || true
    systemctl restart sshd || true

    echo "[2/6] Clearing SSSD cache for new AD users"
    sss_cache -E || true

    echo "[3/6] Checking DCV server status"
    dcv list-servers || true

    echo "[4/6] Fetching instance metadata"
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

    echo "[5/6] Tagging instance as READY"
    aws ec2 create-tags \
      --region "$REGION" \
      --resources "$INSTANCE_ID" \
      --tags Key=LabBootstrap,Value=READY

    echo "[6/6] Bootstrap completed successfully"
    echo "========== LAB BOOTSTRAP END =========="
  EOF
  tags = {
    Name         = "${var.name}-${var.instance_name}-${var.suffix}"
    map-migrated = "DADS45OSDL"
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

