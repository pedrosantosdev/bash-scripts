#!/usr/bin/env bash
set -euo pipefail

# Instalação base do Grafana Alloy.
# Configuração e integração com Loki são responsabilidade do Ansible.
#
# Também remove vestígios de instalações anteriores do Promtail.

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERRO: execute como root." >&2
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERRO: este instalador suporta apenas Debian/Ubuntu via apt." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Removendo instalação anterior do Promtail..."

# Para o serviço antes de remover os arquivos.
systemctl stop promtail 2>/dev/null || true
systemctl disable promtail 2>/dev/null || true

# Remove pacotes, caso o Promtail tenha sido instalado via APT.
apt-get purge -y promtail 2>/dev/null || true

# Remove instalações manuais e configuração/estado conhecidos.
rm -f /usr/local/bin/promtail
rm -f /usr/bin/promtail
rm -f /etc/systemd/system/promtail.service
rm -f /lib/systemd/system/promtail.service
rm -rf /etc/promtail
rm -rf /var/lib/promtail
rm -rf /var/log/promtail

systemctl daemon-reload

echo "==> Instalando Grafana Alloy..."

apt-get update
apt-get install -y ca-certificates curl gpg

install -d -m 0755 /etc/apt/keyrings

curl -fsSL https://apt.grafana.com/gpg-full.key \
    -o /etc/apt/keyrings/grafana.asc

chmod 0644 /etc/apt/keyrings/grafana.asc

cat > /etc/apt/sources.list.d/grafana.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main
EOF

apt-get update
apt-get install -y alloy

# A configuração é deliberadamente deixada para o Ansible.
# Não habilitamos o serviço neste momento para evitar iniciar
# o Alloy sem configuração válida.
systemctl disable alloy 2>/dev/null || true
systemctl stop alloy 2>/dev/null || true

echo
echo "Grafana Alloy instalado com sucesso."
echo "Serviço: alloy"
echo "Configuração: /etc/alloy/config.alloy"
echo "Configuração e ativação do serviço são responsabilidade do Ansible."
