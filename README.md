# Falco playground 

This is a self-contained, local detection lab running on Kubernetes (Kind inside WSL2).
Kubernetes automation scripts can be temperamental, especially on WSL with Kind, Helm, Falco, Grafana, and Prometheus involved. So i will be configuring this infrastructure manually, one step at a time.


- Learn how to bring up and manage Kubernetes clusters with Kind
- Deploy workloads like Falco and Prometheus into namespaces
- Use Helm to install and manage packages with values.yaml
- Understand how Falco works and inspects system calls
- Configure Prometheus to scrape metrics
- Visualize real-time events and alerts in Grafana


# Setting up the environment 

```sh
kind create cluster --name falco-lab --config kind.yaml
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

# Create the relevant namespaces

```sh
hcvb1@h:~/projects/falco-practice$ kubectl create ns falco 
namespace/falco created

hcvb1@h:~/projects/falco-practice$ kubectl create ns monitoring
namespace/monitoring created
```
# Update Helm Repos 

```sh
hcvb1@h:~/projects/falco-practice$ helm repo add falcosecurity https://falcosecurity.github.io/charts || true
"falcosecurity" already exists with the same configuration, skipping

hcvb1@h:~/projects/falco-practice$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
"prometheus-community" already exists with the same configuration, skipping

hcvb1@h:~/projects/falco-practice$ helm repo add grafana https://grafana.github.io/helm-charts || true
"grafana" already exists with the same configuration, skipping

hcvb1@h:~/projects/falco-practice$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "falcosecurity" chart repository
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "prometheus-community" chart repository
Update Complete. ⎈Happy Helming!⎈
```
You can now see the list of Helm repos we have available.

```sh
hcvb1@h:~/projects/falco-practice$ helm repo list 
NAME                    URL                                               
prometheus-community    https://prometheus-community.github.io/helm-charts
falcosecurity           https://falcosecurity.github.io/charts            
grafana                 https://grafana.github.io/helm-charts             
```

Installing Falco with our custom values.yaml file, the custom rules are added here in YAML format this file also enables Prometheus for metrics and setting up the ServiceMonitor.

```sh
hcvb1@h:~/projects/falco-practice$ helm upgrade --install falco falcosecurity/falco --namespace falco -f values.yaml
Release "falco" does not exist. Installing it now.
NAME: falco
LAST DEPLOYED: Thu Apr 10 11:41:59 2025
NAMESPACE: falco
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Falco agents are spinning up on each node in your cluster. After a few
seconds, they are going to start monitoring your containers looking for
security issues.

No further action should be required.
```

# Lets get started on the Falco Pod

After a couple of minutes both the control-plane and the Pod came up and Ready and Running.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl get nodes
NAME                      STATUS   ROLES           AGE     VERSION
falco-lab-control-plane   Ready    control-plane   8m44s   v1.29.2

hcvb1@h:~/projects/falco-practice$ kubectl get pods -n falco
NAME          READY   STATUS    RESTARTS   AGE
falco-flwp6   2/2     Running   0          7m53s
```

For troubleshooting you can run the following to drilldown to see if there are any issues with the pod being created.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl describe pods -n falco falco-flwp6 
hcvb1@h:~/projects/falco-practice$ kubectl logs -n falco falco-flwp6 -c falco
```

The logs should show whether or not the custom rules are being used correctly and mapped to the rules.d file within the Pod. We will later look into inspecting that location
within the container itself.

The kubectl describe command also helps with understanding the current state and the steps taken to get the pod running, with this you scroll to the bottom of the output which will show a small log of the steps the Pod has taken.

Another way to check that the Pod is ready.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco --timeout=180s
pod/falco-flwp6 condition met
```

Next step here is to pre-install the CRDs for kube-prometheus-stack, but whilst doing this I came across some errors so will start going through some troubleshooting steps to see how we can navigate this..

First things first lets check the cluster is healthy

```sh
hcvb1@h:~/projects/falco-practice$ helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout 5m
Error: INSTALLATION FAILED: cannot re-use a name that is still in use
hcvb1@h:~/projects/falco-practice$ kubectl get nodes
NAME                      STATUS   ROLES           AGE   VERSION
falco-lab-control-plane   Ready    control-plane   23m   v1.29.2
hcvb1@h:~/projects/falco-practice$ kubectl get pods -A
NAMESPACE            NAME                                                        READY   STATUS             RESTARTS        AGE
default              nginx-7854ff8877-xd7f6                                      1/1     Running            0               13m
falco                falco-flwp6                                                 2/2     Running            0               18m
kube-system          coredns-76f75df574-6ldvk                                    1/1     Running            0               23m
kube-system          coredns-76f75df574-spzf6                                    1/1     Running            0               23m
kube-system          etcd-falco-lab-control-plane                                1/1     Running            0               23m
kube-system          kindnet-gsft7                                               1/1     Running            0               23m
kube-system          kube-apiserver-falco-lab-control-plane                      1/1     Running            0               23m
kube-system          kube-controller-manager-falco-lab-control-plane             0/1     CrashLoopBackOff   5 (25s ago)     23m
kube-system          kube-proxy-stqbf                                            1/1     Running            0               23m
kube-system          kube-scheduler-falco-lab-control-plane                      1/1     Running            5 (2m38s ago)   23m
local-path-storage   local-path-provisioner-7577fdbbfb-4w58x                     1/1     Running            0               23m
monitoring           kube-prometheus-stack-grafana-c4cd675dd-w99fn               2/3     Running            0               5m46s
monitoring           kube-prometheus-stack-kube-state-metrics-765c7b767b-flwk7   0/1     Running            0               5m46s
monitoring           kube-prometheus-stack-operator-6c94488fc8-fnc4s             1/1     Running            0               5m46s
monitoring           kube-prometheus-stack-prometheus-node-exporter-zbczz        1/1     Running            0               5m46s
hcvb1@h:~/projects/falco-practice$ 
```

That Error message from running the Helm command suggests Helm already sees a release named kube-prometheus-stack in the monitoring namespace - even if the installation didn't fully complete or I think I'm basically trying to re-run it? hmm..

Lets check if Helm sees the release 

```sh
hcvb1@h:~/projects/falco-practice$ helm list -n monitoring
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS  CHART                             APP VERSION
kube-prometheus-stack   monitoring      1               2025-04-10 11:53:59.224057578 +0100 BST failed  kube-prometheus-stack-70.4.2      v0.81.0    
``` 
NICE. 
So I believe that means Helm thinks the release is active, even if the install was interrupted.

So for now i will reinstall it cleanly with a --wait parameter.

```sh
hcvb1@h:~/projects/falco-practice$ helm uninstall kube-prometheus-stack -n monitoring
hcvb1@h:~/projects/falco-practice$ helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout 10m
NAME: kube-prometheus-stack
LAST DEPLOYED: Thu Apr 10 12:09:05 2025
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

Perfect, we now have installed it and can now we can continue with setting up Falco dashboards and Prometheus integration in Grafana.

config maps we are going to create and label here
configmap/falco_dashboard.json created
configmap/falco_dashboard.json labelled
and then the same for Grafana

```sh
hcvb1@h:~/projects/falco-practice$ kubectl create configmap grafana-datasource \
  --from-file=datasource.yaml=grafana_datasource.yaml \
  -n monitoring
kubectl label configmap grafana-datasource -n monitoring grafana_datasource=1 --overwrite
configmap/grafana-datasource created
configmap/grafana-datasource labeled
```

Update the Helm release so Grafana knows to look for these configmaps. This tells Grafana to watch for ConfigMaps labeled as dashboards or datasources and load them.

```sh
hcvb1@h:~/projects/falco-practice$ helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --reuse-values \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.label=grafana_dashboard \
  --set grafana.dashboardsConfigMaps.falco-dashboard="falco-dashboard" \
  --set grafana.sidecar.datasources.enabled=true \
  --set grafana.sidecar.datasources.label=grafana_datasource
Release "kube-prometheus-stack" has been upgraded. Happy Helming!
NAME: kube-prometheus-stack
LAST DEPLOYED: Thu Apr 10 12:17:32 2025
NAMESPACE: monitoring
STATUS: deployed
REVISION: 2
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"

Get Grafana 'admin' user password by running:

  kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Access Grafana local instance:

  export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus-stack" -oname)
  kubectl --namespace monitoring port-forward $POD_NAME 3000

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
```

At this point we want to expose the port and get onto the Grafana UI.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000
Handling connection for 3000
Handling connection for 3000
Handling connection for 3000
Handling connection for 3000
```

Let's also take Grafana's advice above in getting a secret for the Admin password to log on to the UI 

```sh
hcvb1@h:~/projects/falco-practice$ kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
prom-operator
```

Now we have everything setup in Grafana, lets generate some events that will trigger our Falco rules. 

Note: You can also make a cronjob so that it runs the shell script on an interval basis to get more events to visualise in Grafana. 

```sh
crontab -e
* * * * * /home/hcvb1/projects/falco-practice/generate_events.sh 
```

From here if you have installed Ubuntu with WSL which has systemd you can have a look at the service itself, to verify this is in place. 
```sh
sudo systemctl status cron 
```

But for now just running the script from the terminal will do the job.

```sh
hcvb1@h:~/projects/falco-practice$ ./generate_events.sh 
[+] Found nginx pod: nginx-7854ff8877-xd7f6
[+] Generating event: reading /etc/shadow...
If you don't see a command prompt, try pressing enter.
warning: couldn't attach to pod/curl-tester, falling back to streaming logs: unable to upgrade connection: container curl-tester not found in pod curl-tester_default
root:*::0:::::
bin:!::0:::::
daemon:!::0:::::
lp:!::0:::::
sync:!::0:::::
shutdown:!::0:::::
halt:!::0:::::
mail:!::0:::::
news:!::0:::::
uucp:!::0:::::
cron:!::0:::::
ftp:!::0:::::
sshd:!::0:::::
games:!::0:::::
ntp:!::0:::::
guest:!::0:::::
nobody:!::0:::::
pod "curl-tester" deleted
[+] Generating event: writing to /etc/testfile...
Error from server (AlreadyExists): object is being deleted: pods "curl-tester" already exists
[!] Write event failed
[+] Generating event: spawning a shell...
Error from server (AlreadyExists): object is being deleted: pods "curl-tester" already exists
[!] Shell spawn event failed
[+] Generating event: making a network connection (curl http://example.com)...
Error from server (AlreadyExists): object is being deleted: pods "curl-tester" already exists
[!] Curl event failed
[+] Event generation complete.
```

Because the amount of events which are triggered from this script, I have sent the standard out of this to a file name falco_logs.txt which will show the subsequent events of the rules.

# Inspecting the Falco Pod

Lets also check on the health of the Falco pod and exec into the pod and see the rules in the rules.d folder.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl get pods -n falco 
NAME          READY   STATUS    RESTARTS   AGE
falco-flwp6   2/2     Running   0          49m

hcvb1@h:~/projects/falco-practice$ kubctl exec -it -n falco falco-flwp6 -- sh
Command 'kubctl' not found, did you mean:
  command 'kubectl' from snap kubectl (1.32.3)
See 'snap info <snapname>' for additional versions.

hcvb1@h:~/projects/falco-practice$ kubectl exec -it -n falco falco-flwp6 -- sh
Defaulted container "falco" out of: falco, falcoctl-artifact-follow, falco-driver-loader (init), falcoctl-artifact-install (init)
# ls
bin   dev  home  lib    media  opt   product_uuid  run   srv  tmp  var
boot  etc  host  lib64  mnt    proc  root          sbin  sys  usr

# cd etc

# ls
X11                     environment  kernel         pam.d        selinux
adduser.conf            falco        ld.so.cache    passwd       shadow
alternatives            falcoctl     ld.so.conf     passwd-      shells
apt                     fstab        ld.so.conf.d   profile      skel
bash.bashrc             gai.conf     ldap           profile.d    ssl
bindresvport.blacklist  group        libaudit.conf  rc0.d        subgid
ca-certificates         group-       localtime      rc1.d        subuid
ca-certificates.conf    gshadow      logcheck       rc2.d        systemd
cron.d                  gss          login.defs     rc3.d        terminfo
cron.daily              host.conf    logrotate.d    rc4.d        timezone
debconf.conf            hostname     mke2fs.conf    rc5.d        update-motd.d
debian_version          hosts        motd           rc6.d        xattr.conf
default                 init.d       nsswitch.conf  rcS.d
deluser.conf            inputrc      opt            resolv.conf
dpkg                    issue        os-release     rmt
e2scrub.conf            issue.net    pam.conf       security

# cd falco

# ls
config.d  falco.yaml  falco_rules.yaml  rules.d

# cd rules.d

# ls    
rules

# cat rules
- required_engine_version: 10

- rule: Detect curl in container
  desc: Someone ran curl inside a container
  condition: container and proc.name = "curl"
  output: "⚠️ curl detected: user=%user.name command=%proc.cmdline container=%container.id"
  priority: WARNING
  tags: [network, curl, suspicious]

- rule: "Read sensitive file /etc/shadow"
  desc: "Detect any read access to /etc/shadow"
  condition: "evt.type in (open, openat, openat2) and fd.name = /etc/shadow"
  output: "Sensitive file /etc/shadow read (command=%proc.cmdline user=%user.name)"
  priority: WARNING
  tags: [filesystem, sensitive]

- rule: "Write to /etc directory"
  desc: "Detect write operations to any file under /etc"
  condition: "evt.type in (open, openat, openat2) and evt.is_open_write=true and fd.name startswith /etc"
  output: "File in /etc written (command=%proc.cmdline user=%user.name)"
  priority: WARNING
  tags: [filesystem, custom]

- rule: "Write to /etc/sudoers"
  desc: "Detect any write to /etc/sudoers"
  condition: "evt.type in (open, openat, openat2) and evt.is_open_write=true and fd.name = /etc/sudoers"
  output: "Suspicious write to /etc/sudoers (command=%proc.cmdline user=%user.name)"
  priority: CRITICAL
  tags: [privilege_escalation, custom]

- rule: "Shell spawned in container"
  desc: "Detect any shell spawned in a container"
  condition: "proc.name in (sh, bash, zsh) and container.id != host"
  output: "Shell spawned in container (command=%proc.cmdline, container=%container.id)"
  priority: NOTICE
  tags: [container, runtime]

- rule: "Privilege escalation via setuid binary"
  desc: "Detect execution of setuid binaries (e.g., sudo, passwd) in a container"
  condition: "proc.name in (sudo, passwd) and evt.type = execve and container.id != host"
  output: "Setuid binary execution detected (command=%proc.cmdline user=%user.name)"
  priority: CRITICAL
  tags: [privilege_escalation, container]

- rule: shell_in_container
  desc: notice shell activity within a container
  condition: >
    evt.type = execve and 
    evt.dir = < and 
    container.id != host and 
    (proc.name = bash or
    proc.name = ksh)    
  output: >
    shell in a container
    (user=%user.name container_id=%container.id container_name=%container.name 
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)    
  priority: WARNING

- rule: "Unexpected network connection from container"
  desc: "Detect network connection attempts from container processes"
  condition: "evt.type = connect and container.id != host"
  output: "Network connection from container detected (command=%proc.cmdline, connection=%fd.name)"
  priority: NOTICE
  tags: [network, container]# 
```


# Setting up Grafana and Prometheus
 
Going back to Grafana, we want to setup Prometheus as a datasource, as it is scraping the Falco logs. 

To do this, we first we need to create the Prometheus datasource within Grafana, specifying the URL we have for Prometheus
in our grafana_datasource.yaml file.

```sh
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local
  isDefault: true
```
<img width="1505" alt="image" src="https://github.com/user-attachments/assets/b1323a0f-6285-4dac-b860-6deb2db79b12" />

<img width="1505" alt="image" src="https://github.com/user-attachments/assets/b91a2a83-22df-4ccf-8c0b-889571a2afbe" />

And... another issue 
```sh
Post "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local/api/v1/query": dial tcp 10.96.155.186:80: i/o timeout - There was an error returned querying the Prometheus API.
```

So Grafana is trying to query Prometheus using the internal DNS name, but it's either not resolving or Prometheus isn't exposing port 80 here.

So let's check how prometheus is exposed currently

```sh
hcvb1@h:~/projects/falco-practice$ kubectl get svc -n monitoring | grep prometheus
kube-prometheus-stack-alertmanager               ClusterIP   10.96.183.102   <none>        9093/TCP,8080/TCP            33m
kube-prometheus-stack-grafana                    ClusterIP   10.96.130.77    <none>        80/TCP                       33m
kube-prometheus-stack-kube-state-metrics         ClusterIP   10.96.217.114   <none>        8080/TCP                     33m
kube-prometheus-stack-operator                   ClusterIP   10.96.92.120    <none>        443/TCP                      33m
kube-prometheus-stack-prometheus                 ClusterIP   10.96.155.186   <none>        9090/TCP,8080/TCP            33m
kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.96.168.4     <none>        9100/TCP                     33m
prometheus-operated                              ClusterIP   None            <none>        9090/TCP                     33m
hcvb1@h:~/projects/falco-practice$ 
```

So kube-prometheus-stack-prometheus is listening on port 9090 and not 80, this is why Grafana is throwing 
```sh
dial tcp 10.96.155.186:80 i/o timeout
```

So all we have to do here is append the port we have here to Grafana.

Also noticed i don't seem to be using the correct port, that needs to be corrected.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl port-forward -n falco svc/falco-metrics 8765:8765
Forwarding from 127.0.0.1:8765 -> 8765
Forwarding from [::1]:8765 -> 8765
Handling connection for 8765
Handling connection for 8765
```
When you browse to this you will see the raw events from Falco
<img width="1508" alt="image" src="https://github.com/user-attachments/assets/9fdef65e-f715-47f5-81b6-3cecebb197bc" />

```sh
hcvb1@h:~/projects/falco-practice$ kubectl get servicemonitors -n falco
No resources found in falco namespace.

hcvb1@h:~/projects/falco-practice$ helm upgrade falco falcosecurity/falco -n falco -f values.yaml
Release "falco" has been upgraded. Happy Helming!
NAME: falco
LAST DEPLOYED: Thu Apr 10 12:59:37 2025
NAMESPACE: falco
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

Will now expose Prometheus so we can check whether it is scraping our Falco service.

```sh
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
```

Now we probably should have a look at the serviceMonitor to see whether we can see our falco service.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl get servicemonitor -n falco
No resources found in falco namespace.

hcvb1@h:~/projects/falco-practice$ kubectl get servicemonitor
No resources found in default namespace.

hcvb1@h:~/projects/falco-practice$ kubectl get servicemonitor -A
NAMESPACE    NAME                                             AGE
monitoring   kube-prometheus-stack-alertmanager               58m
monitoring   kube-prometheus-stack-apiserver                  58m
monitoring   kube-prometheus-stack-coredns                    58m
monitoring   kube-prometheus-stack-grafana                    58m
monitoring   kube-prometheus-stack-kube-controller-manager    58m
monitoring   kube-prometheus-stack-kube-etcd                  58m
monitoring   kube-prometheus-stack-kube-proxy                 58m
monitoring   kube-prometheus-stack-kube-scheduler             58m
monitoring   kube-prometheus-stack-kube-state-metrics         58m
monitoring   kube-prometheus-stack-kubelet                    58m
monitoring   kube-prometheus-stack-operator                   58m
monitoring   kube-prometheus-stack-prometheus                 58m
monitoring   kube-prometheus-stack-prometheus-node-exporter   58m
```

So there isn't a ServiceMonitor for Falco, which means Prometheus has no instructions to scrape Falco's metrics service.

Will now create a ServiceMonitor manually that matches the falco-metrics service.

```sh
hcvb1@h:~/projects/falco-practice$ vim falco-servicemonitor.yaml
hcvb1@h:~/projects/falco-practice$ kubectl get svc falco-metrics -n falco -o yaml | grep port:
    port: 8765

hcvb1@h:~/projects/falco-practice$ kubectl apply -f falco-servicemonitor.yaml
servicemonitor.monitoring.coreos.com/falco created

hcvb1@h:~/projects/falco-practice$ kubectl get servicemonitor -n monitoring
NAME                                             AGE
falco                                            12s
kube-prometheus-stack-alertmanager               62m
kube-prometheus-stack-apiserver                  62m
kube-prometheus-stack-coredns                    62m
kube-prometheus-stack-grafana                    62m
kube-prometheus-stack-kube-controller-manager    62m
kube-prometheus-stack-kube-etcd                  62m
kube-prometheus-stack-kube-proxy                 62m
kube-prometheus-stack-kube-scheduler             62m
kube-prometheus-stack-kube-state-metrics         62m
kube-prometheus-stack-kubelet                    62m
kube-prometheus-stack-operator                   62m
kube-prometheus-stack-prometheus                 62m
kube-prometheus-stack-prometheus-node-exporter   62m
```
ServiceMonitor config will be in the above file in the repo called falco-servicemonitor.yaml

Perfect!

Also found out that ServiceMonitors match by port name, not port number, one of those subtle but critical details when working with Prometheus and Kubernetes.

```sh
hcvb1@h:~/projects/falco-practice$ kubectl patch svc falco-metrics -n falco --type='json' \
  -p='[{"op": "replace", "path": "/spec/ports/0/name", "value":"http"}]'
service/falco-metrics patched

hcvb1@h:~/projects/falco-practice$ kubectl apply -f falco-servicemonitor.yaml
servicemonitor.monitoring.coreos.com/falco unchanged
```
<img width="1694" alt="image" src="https://github.com/user-attachments/assets/2821b822-b42d-43e0-ad15-7573d4ce38fd" />


Everything should be all setup and running, we can now go to Grafana to add a custom dashboard to view the events live
and then generate some more events by issuing the generate_events.sh script to act as a potential adversary.

In Grafana you can create a new dashboard and start to add panels. Will stick to some simple panels for now:

Total Falco events
```sh
rate(falcosecurity_scap_n_evts_total[$__rate_interval])
```
Falco CPU Usage
```sh
rate(falcosecurity_falco_cpu_usage_ratio[1m]) * 100
```
Rule Matches by Name (Top Offenders)
```sh
rate(falcosecurity_falco_rules_matches_total[$__rate_interval])
```
Rule Matches by Severity
```sh
sum by (priority) (rate(falcosecurity_falco_rules_matches_total[5m]))
```
This is how Grafana should look at the end. 

<img width="1759" alt="image" src="https://github.com/user-attachments/assets/0e25d3b4-c549-4ef4-9ed1-8a78aea3a72b" />


# Lab objectives
So the goal of this was really to understand how to bring up and manage Kubernetes clusters, how to deploy workloads like Falco and Prometheus
into namespaces. 

- How Helm works as a package manager for Kubernetes installing, upgrading charts, using the values.yaml as our config file. 
- Really getting into how Falco works and how the events look, and understanding how we can use this runtime security tool 
for detecting threats by monitoring system calls inside our containers
- Working with Prometheus and Grafana was a bit challenging but made it there in the end, how we can scrape metrics from a source 
using the Prometheus Operator and using labels and port names actually matter when configuring ServiceMonitor
- Falco metrics are Prometheus-compatible but need to be exposed on the correct port-name so the ServiceMonitor can find it 

Below is a map of all the Kubernetes resources created while getting this setup.

<img width="1518" alt="image" src="https://github.com/user-attachments/assets/e4b7b2e8-f80f-412a-8268-b37e74638684" />
