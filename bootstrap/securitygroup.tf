################################################################################
# Cluster Security Group
################################################################################

resource "aws_security_group" "cluster" {
  name        = "terraform-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description                = "Node groups to cluster API"
    from_port                  = 443
    to_port                    = 443
    protocol                   = "tcp"
    cidr_blocks                = ["0.0.0.0/0"]
  }

  egress {
    description                = "Cluster API to node groups"
    from_port                  = 443
    to_port                    = 443
    protocol                   = "tcp"
    cidr_blocks                = ["0.0.0.0/0"]
  }

  
}

################################################################################
# Node Security Group
################################################################################


resource "aws_security_group" "node" {
  name        = "terraform-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description                   = "Cluster API to node groups"
    from_port                     = 443
    to_port                       = 443
    protocol                      = "tcp"
    cidr_blocks                = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Cluster API to node kubelets"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks                = ["0.0.0.0/0"]
  }
  ingress {
    description      = "Node to node CoreDNS"
    from_port        = 53
    to_port          = 53
    protocol         = "tcp"
    self             = true
  }

  egress {
    description                   = "Node groups to cluster API"
    from_port                     = 433
    to_port                       = 433
    protocol                      = "tcp"
    cidr_blocks                = ["0.0.0.0/0"]
  }

  egress {
    description      = "Node to node CoreDNS"
    from_port        = 53
    to_port          = 53
    protocol         = "tcp"
    self             = true
  }
  ingress {
    description      = "Node to node CoreDNS"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    self             = true
  }
  ingress {
    description      = "Node to node CoreDNS"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    self             = true
  }
  egress {
    description      = "Egress all HTTPS to internet"
    from_port        = 433
    to_port          = 433
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description      = "Egress NTP/TCP to internet"
    from_port        = 123
    to_port          = 123
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description      = "Egress NTP/UDP to internet"
    from_port        = 123
    to_port          = 123
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "terraform-eks-demo"
  }
}