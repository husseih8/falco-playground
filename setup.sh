#!/bin/bash
set -euo pipefail

function delete_existing_cluster() {
  if kind get clusters | grep -q "^falco-lab$"; then
    echo "[INFO] Cluster 'falco-lab' already exists. Deleting it..."
    kind delete cluster --name falco-lab || true
  fi
}

if [ "${1:-}" == "up" ]; then
  echo "[+] Creating kind cluster..."
  delete_existing_cluster
  kind create cluster --name falco-lab --config kind.yaml
  kubectl cluster-info --context kind-falco-lab

  echo "[+] Creating namespaces..."
  kubectl create ns falco || true
  kubectl create ns monitoring || true

  echo "[+] Adding and updating Helm repos..."
  helm repo add falcosecurity https://falcosecurity.github.io/charts || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
  helm repo update

  echo "[+] Installing Falco..."
  helm upgrade --install falco falcosecurity/falco \
    --namespace falco \
    -f values.yaml

  echo "[+] Deploying nginx workload..."
  kubectl create deployment nginx --image=nginx || true

  echo "[+] Waiting for Kind node to be ready..."
  until kubectl get nodes | grep -q "Ready"; do
    echo "[INFO] Waiting for node to be Ready..."
    sleep 5
  done

  echo "[+] Pre-installing kube-prometheus-stack CRDs..."
  rm -rf kube-prometheus-stack || true
  helm pull prometheus-community/kube-prometheus-stack --untar
  kubectl apply -f kube-prometheus-stack/crds || true
  rm -rf kube-prometheus-stack

  helm uninstall kube-prometheus-stack -n monitoring || true
  sleep 5

  helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace --wait --timeout 5m || {
    echo "[!] Failed to install kube-prometheus-stack. Check 'kubectl get events -n monitoring'"
    exit 1
  }

  echo "[+] Waiting for Grafana pod to be Ready..."
  kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s || {
    echo "[!] Grafana did not become ready in time."
    exit 1
  }

  echo "[+] Loading custom dashboards and datasources..."
  kubectl create configmap falco-dashboard \
    --from-file=falco_dashboard.json=falco_dashboard.json \
    -n monitoring || true
  kubectl label configmap falco-dashboard -n monitoring grafana_dashboard=1 --overwrite

  kubectl create configmap grafana-datasource \
    --from-file=datasource.yaml=grafana_datasource.yaml \
    -n monitoring || true
  kubectl label configmap grafana-datasource -n monitoring grafana_datasource=1 --overwrite

  helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --reuse-values \
    --set grafana.sidecar.dashboards.enabled=true \
    --set grafana.sidecar.dashboards.label=grafana_dashboard \
    --set grafana.dashboardsConfigMaps.falco-dashboard="falco-dashboard" \
    --set grafana.sidecar.datasources.enabled=true \
    --set grafana.sidecar.datasources.label=grafana_datasource

  echo "[+] Port-forwarding Grafana on http://localhost:3000..."
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &

  echo "[+] Waiting for Falco pod(s) to be Ready..."
  kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco --timeout=180s

  echo "[+] Lab setup complete."
  echo "Grafana: http://localhost:3000"
  echo "To get the Grafana admin password:"
  echo "kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d; echo"
  echo "To tail Falco logs: make logs"
  echo "To generate events: ./generate_events.sh"

elif [ "${1:-}" == "logs" ]; then
  echo "[+] Tailing Falco logs..."
  kubectl logs -n falco -l app.kubernetes.io/name=falco -f

elif [ "${1:-}" == "down" ]; then
  echo "[+] Uninstalling Falco..."
  helm uninstall falco -n falco || true

  echo "[+] Uninstalling Prometheus & Grafana..."
  helm uninstall kube-prometheus-stack -n monitoring || true

  echo "[+] Deleting all kind clusters..."
  for cluster in $(kind get clusters); do
    echo "[+] Deleting cluster: $cluster"
    kind delete cluster --name "$cluster" || true
  done

  echo "[+] Cleanup complete."
else
  echo "Usage: $0 {up|logs|down}"
  exit 1
fi
