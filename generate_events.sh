#!/bin/bash
set -e

# Check for nginx pod before proceeding
POD=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$POD" ]; then
    echo "[!] No nginx pod found. Deploy one with: kubectl run nginx --image=nginx --labels=app=nginx"
else
    echo "[+] Found nginx pod: $POD"
fi

echo "[+] Generating event: reading /etc/shadow..."
kubectl run curl-tester --rm -i --tty --image=alpine -- cat /etc/shadow || echo "[!] Failed to read /etc/shadow"

echo "[+] Generating event: writing to /etc/testfile..."
kubectl run curl-tester --rm -i --tty --image=alpine -- sh -c "echo 'Falco Test' > /etc/testfile" || echo "[!] Write event failed"

echo "[+] Generating event: spawning a shell..."
kubectl run curl-tester --rm -i --tty --image=alpine -- sh -c "sh -c 'echo Shell spawned'" || echo "[!] Shell spawn event failed"

echo "[+] Generating event: making a network connection (curl http://example.com)..."
kubectl run curl-tester --rm -i --tty --image=alpine -- sh -c "apk add --no-cache curl && curl -s http://example.com" || echo "[!] Curl event failed"

echo "[+] Event generation complete."
