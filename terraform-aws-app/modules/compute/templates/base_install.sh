set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Everything below ends up in /var/log/cloud-init-output.log - check it first
# if an instance does not behave.

apt-get update -y
apt-get install -y ca-certificates curl gnupg nginx

# --- Docker Engine from Docker's official apt repository -------------------
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker ubuntu

# nginx comes up with the default site; each role replaces it below.
systemctl enable nginx
