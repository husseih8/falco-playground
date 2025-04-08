# Falco playground 

## Goal

Part 1

1. Create a basic KinD Cluster: Refering to a kind.yaml.

2. Create a Namespace + ConfigMap: Deploys a custom-rule.yaml into the Falco namespace.

3. Install Falco: With the custom rule loaded from the ConfigMap.

4. Deploy a nginx server or similar: A simple workload to help test detection by generating some events.

Part 2

5. Install Prometheus + Grafana: Mainly to practice how events are viewed in a visualisation and monitoring platform

6. Configuring Grafana: Which will load a Falco dashboard and datasource.

7. Set-up Port Forwarding to Grafana: Making it accessible at http://localhost:3000.

8. Tails Falco Logs: Immediately shows detections live, and for debugging and troubleshooting.


## Setup

```bash
# Theres a Makefile within this repository which will bring the whole infrastructure up or down, the script is called ./setup.sh
# Example running make up

make up
./setup.sh up
[+] Creating kind cluster...
[INFO] Cluster 'falco-lab' already exists. Deleting it...
Deleting cluster "falco-lab" ...
Deleted nodes: ["falco-lab-control-plane"]
Creating cluster "falco-lab" ...
 ✓ Ensuring node image (kindest/node:v1.29.2) 🖼 
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-falco-lab"
You can now use your cluster with:

kubectl cluster-info --context kind-falco-lab

```

