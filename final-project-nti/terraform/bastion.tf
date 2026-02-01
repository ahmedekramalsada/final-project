# --- Bastion Host for EKS Access ---

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  # SSH access from anywhere (you can restrict this to your IP)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "bastion-sg"
    Environment = "dev"
    Project     = "devops-final"
  }
}

# IAM Role for Bastion Host
resource "aws_iam_role" "bastion" {
  name = "bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "bastion-role"
    Environment = "dev"
    Project     = "devops-final"
  }
}

# IAM Policy for EKS Access
resource "aws_iam_role_policy" "bastion_eks" {
  name = "bastion-eks-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach SSM policy for Session Manager access (optional but recommended)
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile for Bastion
resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-profile"
  role = aws_iam_role.bastion.name
}

# Key Pair for SSH access
resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key"
  public_key = file("~/.ssh/terraform-key.pub")

  tags = {
    Name        = "bastion-key"
    Environment = "dev"
    Project     = "devops-final"
  }
}

# Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.bastion.key_name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    
    # Update system
    dnf update -y
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Install AWS CLI v2 (already installed on AL2023, but ensure latest)
    dnf install -y aws-cli
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Configure kubectl for EKS
    mkdir -p /home/ec2-user/.kube
    
    # Create a script to configure kubectl
    cat > /home/ec2-user/configure-eks.sh << 'SCRIPT'
    #!/bin/bash
    aws eks update-kubeconfig --region us-east-1 --name devops-cluster
    echo "kubectl configured for devops-cluster"
    kubectl get nodes
    SCRIPT
    
    chmod +x /home/ec2-user/configure-eks.sh
    chown -R ec2-user:ec2-user /home/ec2-user/
    
    echo "Bastion host setup complete!"
  EOF

  tags = {
    Name        = "bastion-host"
    Environment = "dev"
    Project     = "devops-final"
  }

  depends_on = [module.eks]
}

# Add EKS access for Bastion Role
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

# Security group rule to allow bastion to access EKS cluster API
resource "aws_security_group_rule" "bastion_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow bastion host to access EKS API"
}

# --- Outputs ---
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ~/.ssh/terraform-key ec2-user@${aws_instance.bastion.public_ip}"
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host (for SSM Session Manager)"
  value       = aws_instance.bastion.id
}
