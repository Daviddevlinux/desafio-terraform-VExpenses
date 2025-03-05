# Desafio Online da VExpenses - Processo Seletivo para Estágio em DevOps

## Objetivo

Este repositório contém a minha solução do desafio de infraestrutura como código (IaC) usando **Terraform**. Conforme solicitado e explicado no processo seletivo da VExpenses, o objetivo é demonstrar habilidades em automação, segurança e configuração de servidores, usando recursos da AWS para provisionamento de uma infraestrutura básica. Veja tudo o que fiz:

## Descrição Técnica e Curiosidade

Resumindo, o arquivo **main.tf** contém o código Terraform que provisiona os seguintes recursos na **AWS**. O código se parece bastante com o de um projeto que fiz a um tempo. Caso deseje ver, só seguir este link: https://gitlab.com/DavidMaiaDev/projeto-phoebus-devops-david

# Vamos ao entendimento do arquivo: _Análise Técnica do Código Terraform - (Tarefa 1)_

### Provedor AWS

Define a **região AWS** como us-east-1 para o provisionamento dos recursos.

```bash
provider "aws" {
  region = "us-east-1"
}
```

### Variáveis de Projeto

Variáveis usadas são para parametrizar o nome do projeto (VExpenses) e o nome do candidato (Que nesse caso, irei colocar o meu). Estas variáveis são utilizadas em vários recursos, facilitando a identificação desses recursos.

```bash
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}
```

### Chave SSH

Uma chave privada é gerada com o algoritmo RSA de 2048 bits, que é usada para criar um Key Pair na AWS. A chave pública associada será usada para acessar a instância EC2 via SSH.

```bash
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```

### Criação de VPC

A VPC é criada com o bloco CIDR 10.0.0.0/16 para suportar até 65.536 endereços IP. Pelo que vi, o suporte a DNS e hostnames está habilitado.

```bash
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
```

### Subnets

Uma sub-rede associada à VPC é criada no bloco CIDR 10.0.1.0/24 (256 endereços IP) na zona de disponibilidade "us-east-1a".

```bash
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```

### Internet Gateway e Tabela de Rotas

Uma Internet Gateway é criada para permitir acesso à internet. A Tabela de Rotas é configurada com uma rota padrão para todo o tráfego de saída (0.0.0.0/0) via o Internet Gateway.

```bash
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}
```

### Grupos de Segurança

Um Security Group aqui é criado para controlar o tráfego da instância EC2 que vai ser iniciada:

**Entrada:** Permite conexões SSH (porta 22) de qualquer endereço IP. (Algo que não me parece ser tão seguro)

**Saída:** Permite todo o tráfego de saída.

```bash
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}
```

### A instanciação da EC2

Uma instância EC2 do tipo t2.micro vai ser criada usando a imagem mais recente do Debian, que nesse casdo seria o 12.

A instância está configurada com algumas características:

- 20 GB de armazenamento. onde haverá a execução de um script de inicialização (user_data) para atualizar e melhorar os pacotes do sistema.

- Associada à sub-rede e ao grupo de segurança, com um endereço IP público para acesso via SSH.

```bash
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```

### Outputs

A solução vai gerar dois outputs:

- Chave privada para acessar a instância da EC2

- O endereço IP público da instância EC2

```bash
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
```
