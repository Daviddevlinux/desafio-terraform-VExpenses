#!/bin/bash
# Atualiza os pacotes
apt-get update -y
apt-get upgrade -y

# Instala o Nginx
apt-get install -y nginx

# Inicia e habilita o Nginx para iniciar no boot
systemctl start nginx
systemctl enable nginx

# Desabilita o login SSH como root
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Altera a porta padrão do SSH de 22 para 2222
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

# Reinicia o serviço SSH para aplicar as mudanças
systemctl restart sshd