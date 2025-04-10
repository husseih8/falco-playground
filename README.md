# Falco playground 

Getting familiar with running a kind cluster with falco 

## Goal

- Learn how to bring up and manage Kubernetes clusters with Kind
- Deploy workloads like Falco and Prometheus into namespaces
- Use Helm to install and manage packages with values.yaml
- Understand how Falco works and inspects system calls
- Configure Prometheus to scrape metrics
- Visualize real-time events and alerts in Grafana


## Setup

Notes:
You're creating a self-contained, local detection lab running on Kubernetes (Kind inside WSL2).

This lab lets you:

Goal	How you're doing it
Simulate a real cluster	Using Kind (Kubernetes in Docker)
Detect suspicious activity in containers	Using Falco (runtime threat detection)
Trigger events for testing	Using a script or manually running commands in test pods
Collect and visualize detection logs	Using Prometheus + Grafana
Store detections as code	Using custom-rule.yaml (editable YAML rules for Falco)
Run everything automatically	Using setup.sh and optionally Makefile

Kubernetes automation scripts can be temperamental, especially on WSL with Kind, Helm, Falco, Grafana, and Prometheus involved.




setting up the environment 

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

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂


hcvb1@h:~/projects/falco-practice$ kubectl create ns falco 
namespace/falco created
hcvb1@h:~/projects/falco-practice$ kubectl create ns monitoring
namespace/monitoring created
hcvb1@h:~/projects/falco-practice$ 


Create Namespaces


hcvb1@h:~/projects/falco-practice$ kubectl get pods -n falco
NAME          READY   STATUS    RESTARTS   AGE
falco-tb6fn   2/2     Running   0          16h

Update Helm Repos 

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
hcvb1@h:~/projects/falco-practice$ 



hcvb1@h:~/projects/falco-practice$ helm repo list 
NAME                    URL                                               
prometheus-community    https://prometheus-community.github.io/helm-charts
falcosecurity           https://falcosecurity.github.io/charts            
grafana                 https://grafana.github.io/helm-charts             
hcvb1@h:~/projects/falco-practice$ 

Installing Falco with our custom values.yaml, the custom rules are added here in YYAML format 
this file also enabled prometheus for metrics and a ServiceMonitor field


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


Tip: 
You can easily forward Falco events to Slack, Kafka, AWS Lambda and more with falcosidekick. 
Full list of outputs: https://github.com/falcosecurity/charts/tree/master/charts/falcosidekick.
You can enable its deployment with `--set falcosidekick.enabled=true` or in your values.yaml. 
See: https://github.com/falcosecurity/charts/blob/master/charts/falcosidekick/values.yaml for configuration values.

deploying a sample nginx workload

kubectl create deployment nginx --image=nginx
deployment.apps/nginx created

Waiting for Kind node and falco to be ready 

hcvb1@h:~/projects/falco-practice$ kubectl get nodes
NAME                      STATUS   ROLES           AGE     VERSION
falco-lab-control-plane   Ready    control-plane   8m44s   v1.29.2

You will have to wait a couple minutes in order to see the pod in a running state

hcvb1@h:~/projects/falco-practice$ kubectl get pods -n falco
NAME          READY   STATUS    RESTARTS   AGE
falco-flwp6   2/2     Running   0          7m53s
hcvb1@h:~/projects/falco-practice$ 

For troubleshooting you can run the following to drilldown into an issues with the pod being created 

hcvb1@h:~/projects/falco-practice$ kubectl describe pods -n falco falco-flwp6 
hcvb1@h:~/projects/falco-practice$ kubectl logs -n falco falco-flwp6 -c falco

The logs should show whether or not the custom rules are being used correctly and mapped to 
the rules.d file within the pod.

describe will help with understanding the current state and the steps taken to get the pod running which will 
a small log at the bottom of the output. 

Another way to check that the Pod is ready 

hcvb1@h:~/projects/falco-practice$ kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco --timeout=180s
pod/falco-flwp6 condition met


Next step here is to pre-install the CRDs for kube-prometheus-stack, but i hit a bit of a snag 
so will start going through some troubleshooting steps to see how we can navigate this issue

First things first lets check the cluster is healthy

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

That Error message from running the Helm command suggests Helm already sees a release 
named kube-prometheus-stack in the monitoring namespace - even if the installation didn't fully complete or I'm
im basically trying to re-run it? hmm

Lets check if Helm sees the release 

hcvb1@h:~/projects/falco-practice$ helm list -n monitoring
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS  CHART                             APP VERSION
kube-prometheus-stack   monitoring      1               2025-04-10 11:53:59.224057578 +0100 BST failed  kube-prometheus-stack-70.4.2      v0.81.0    

NICE.So i believe that means Helm thinks the release is active, even if the install was interrupted.

So for now i will reinstall it cleanly with a --wait parameter

helm uninstall kube-prometheus-stack -n monitoring

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
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"

Get Grafana 'admin' user password by running:

  kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Access Grafana local instance:

  export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus-stack" -oname)
  kubectl --namespace monitoring port-forward $POD_NAME 3000

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.


Perfect, we now have installed it and can now continue with setting up Falco dashboards and Prometheus integration
in Grafana.

config maps we are going to create and label here 
configmap/falco_dashboard.json created
configmap/falco_dashboard.json labelled

and then the same for Grafana
hcvb1@h:~/projects/falco-practice$ kubectl create configmap grafana-datasource \
  --from-file=datasource.yaml=grafana_datasource.yaml \
  -n monitoring
kubectl label configmap grafana-datasource -n monitoring grafana_datasource=1 --overwrite
configmap/grafana-datasource created
configmap/grafana-datasource labeled


update the Helm release so Grafana knows to look for these configmaps
This tells Grafana to watch for ConfigMaps labeled as dashboards or datasources and load them.


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


At this point we want to expose the port and get onto the Grafana UI
hcvb1@h:~/projects/falco-practice$ kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000
Handling connection for 3000
Handling connection for 3000
Handling connection for 3000
Handling connection for 3000

a nice practice is to also get a password via a secret
 

hcvb1@h:~/projects/falco-practice$ kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
prom-operator

Now we have everything setup in Grafana, lets generate some events that will trigger our Falco rules 

You can also make a cronjob so that it runs the shell script on an interval basis to get more events to visualise 
in Grafana. 

crontab -e
* * * * * /home/hcvb1/projects/falco-practice/generate_events.sh 

From here if you have installed Ubuntu with WSL which has systemd you can have a look at the service itself, to 
verify this is in place. 

sudo systemctl status cron 

But for now just running the script from the terminal is fine.

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

Because the amount of events which are triggered from this script, I have sent the standard out of this to a file 
name falco_logs.txt which will show the events of the rules being triggered. 

Lets also check on the health of the Falco pod and exec into the pod and see the rules in the rules.d folder

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
# cd etc falco
sh: 4: cd: can't cd to etc
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

 
Going back to Grafana, we want to setup the prometheus datasource as a feed, as it is scraping the Falco logs 

To do this first we need to create the Prometheus datasource within Grafana, specifying the URL we have for Prometheus
in our grafana_datasource.yaml file.

apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local
  isDefault: true

And... another issue 
Post "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local/api/v1/query": dial tcp 10.96.155.186:80: i/o timeout - There was an error returned querying the Prometheus API.

So Grafana is trying to query Prometheus using the internal DNS name, but it's either
not resolving or Prometheus isn't exposing port 80 here

So let's check how prometheus is exposed currently

hcvb1@h:~/projects/falco-practice$ kubectl get svc -n monitoring | grep prometheus
kube-prometheus-stack-alertmanager               ClusterIP   10.96.183.102   <none>        9093/TCP,8080/TCP            33m
kube-prometheus-stack-grafana                    ClusterIP   10.96.130.77    <none>        80/TCP                       33m
kube-prometheus-stack-kube-state-metrics         ClusterIP   10.96.217.114   <none>        8080/TCP                     33m
kube-prometheus-stack-operator                   ClusterIP   10.96.92.120    <none>        443/TCP                      33m
kube-prometheus-stack-prometheus                 ClusterIP   10.96.155.186   <none>        9090/TCP,8080/TCP            33m
kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.96.168.4     <none>        9100/TCP                     33m
prometheus-operated                              ClusterIP   None            <none>        9090/TCP                     33m
hcvb1@h:~/projects/falco-practice$ 

kube-prometheus-stack-prometheus is listening on port 9090 and not 80 
This is why Grafana is throwing 
dial tcp 10.96.155.186:80 i/o timeout

So all we have to do here is append the port we have here to Grafana

Some more troubleshooting, just realised that the port i have for metrics was 8766 instead of 
8765 - 

hcvb1@h:~/projects/falco-practice$ kubectl port-forward -n falco svc/falco-metrics 8765:8765
Forwarding from 127.0.0.1:8765 -> 8765
Forwarding from [::1]:8765 -> 8765
Handling connection for 8765
Handling connection for 8765
^Chcvb1@h:~/projects/falco-practicekubectl get servicemonitors -n falcoco
No resources found in falco namespace.
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
NOTES:
Falco agents are spinning up on each node in your cluster. After a few
seconds, they are going to start monitoring your containers looking for
security issues.


No further action should be required.


Tip: 
You can easily forward Falco events to Slack, Kafka, AWS Lambda and more with falcosidekick. 
Full list of outputs: https://github.com/falcosecurity/charts/tree/master/charts/falcosidekick.
You can enable its deployment with `--set falcosidekick.enabled=true` or in your values.yaml. 
See: https://github.com/falcosecurity/charts/blob/master/charts/falcosidekick/values.yaml for configuration values.

Can bring up prometheus here aswell to view the service is there

kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

Now we can troubleshoot the serviceMonitor to see whether it can see our falco service

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

From this we are not seeing a ServiceMonitor for Falco, Prometheus has no instructions to scrape Falco's metrics service (falco-metrics).

Will now create a ServiceMonitor manually that matches the falco-metrics service.

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

Perfect

Also found out that ServiceMonitors match by port name, not port number, one of those subtle but critical details when working with Prometheus and Kubernetes.



hcvb1@h:~/projects/falco-practice$ kubectl patch svc falco-metrics -n falco --type='json' \
  -p='[{"op": "replace", "path": "/spec/ports/0/name", "value":"http"}]'
service/falco-metrics patched
hcvb1@h:~/projects/falco-practice$ kubectl apply -f falco-servicemonitor.yaml
servicemonitor.monitoring.coreos.com/falco unchanged

Everything should be all setup and running, we can now go to Grafana to add a custom dashboard to view the events live
and can generate some more events by issuing the generate_events.sh script to act as a potential adversary.

In Grafana you can create a new dashboard and start to add panels. Will stick to some simple panels for now:

Total Falco events
rate(falcosecurity_scap_n_evts_total[$__rate_interval])

Falco CPU Usage
rate(falcosecurity_falco_cpu_usage_ratio[1m]) * 100

Rule Matches by Name (Top Offenders)
rate(falcosecurity_falco_rules_matches_total[$__rate_interval])

Rule Matches by Severity
sum by (priority) (rate(falcosecurity_falco_rules_matches_total[5m]))

This is how Grafana should look at the end. 



So the goal of this was really to understand how to bring up and manage Kubernetes clusters, how to deploy workloads like Falco and Prometheus
into namespaces. 

How Helm works as a package manager for Kubernetes installing, upgrading charts, using the values.yaml as our config file. 

And really getting into how Falco works and how the events look, and understanding how we can use this runtime security tool 
for detecting threats by monitoring system calls inside our containers

Working with Prometheus and Grafana was a bit challenging but made it there in the end, how we can scrape metrics from a source 
using the Prometheus Operator and using labels and port names actually matter when configuring ServiceMonitor

Falco metrics are Prometheus-compatible but need to be exposed on the correct port name so the ServiceMonitor can find it 


