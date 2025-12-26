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
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  # Updated user data script
  user_data = <<-EOF
    #!/bin/bash

    # sed -i 's/^PasswordAuthentication no$/PasswordAuthentication yes/' /etc/ssh/sshd_config
    
    # bash /root/.login-kb/remove.bash
    # bash /root/.login-kb/login_ad.bash
    # rm -f /root/.bash_history
    # rm -f /home/centos/.bash_history
    # rm -f /home/cloud-user/.bash_history
    # echo "ad_gpo_access_control = disabled" >> /etc/sssd/sssd.conf

    #!/bin/bash

    LOG=/var/log/user-data.log
    exec > >(tee -a $LOG) 2>&1

    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=ap-south-1

    function mark_failed() {
      aws ec2 create-tags \
        --region $REGION \
        --resources $INSTANCE_ID \
        --tags Key=LabStatus,Value=FAILED
      exit 1
    }

    function mark_success() {
      aws ec2 create-tags \
        --region $REGION \
        --resources $INSTANCE_ID \
        --tags Key=LabStatus,Value=BOOTSTRAP_OK
    }

    echo "==== USER DATA START ===="

    systemctl restart sshd || mark_failed

    echo "nameserver 10.10.17.253" > /etc/resolv.conf || mark_failed

    until nslookup sumedhalabs.com; do sleep 5; done

    systemctl stop sssd || true
    rm -rf /var/lib/sss/db/* || mark_failed
    systemctl start sssd || mark_failed

    systemctl restart dcvserver || mark_failed

    mark_success



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
