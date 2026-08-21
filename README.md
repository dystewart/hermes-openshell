# hermes-openshell
This repository contains resources and instructions for deploying hermes agent with a openai api key in OpenShell, running in OpenShift

# Run Hermes agent with chatGPT inside OpenShell on OpenShift

> **SECURITY POSTURE** — This runbook reproduces an evaluation configuration. This setup is experimental, the sandbox uses the privileged SCC, the gateway runs with TLS disabled, and unauthenticated user calls are allowed only behind oc port-forward. Never expose this configuration through an OpenShift Route.

# 1. Outcome and architecture

At completion, Hermes agent runs inside an OpenShell-managed sandbox pod. Hermes sends model requests to OpenShell's internal inference endpoint; the OpenShell gateway injects credentials and forwards requests to OpenAI. The service-account private key is not copied into the sandbox.

| Component | Responsibility |
| --- | --- |
| OpenShell CLI on Mac | Administers the remote gateway through a local port-forward. |
| OpenShell gateway | Creates sandboxes, stores provider configuration, refreshes credentials, and routes inference. |
| test-sandbox | OpenShell sandbox, runs Python, Google ADK, agent code, and tools under OpenShell policy. |
| ChatGPT | Hosts the selected LLM |

# 2. Values used in this runbook

```bash
NAMESPACE=openshell-test
HELM_RELEASE=openshell-test
GATEWAY_SERVICE=openshell-test
SANDBOX_SERVICE_ACCOUNT=openshell-test-sandbox
SANDBOX_NAME=test-sandbox
OPENSHELL_VERSION=0.0.98
LOCAL_GATEWAY_PORT=8080
```

# 3. Prerequisites

- OpenShift 4.x with oc configured and cluster-admin-equivalent rights for CRDs and SCC bindings.

- Helm 3.x on the Mac.

- OpenShell CLI v0.0.98 

- OpenAI api key

> **CREDENTIAL SAFETY** — Do not paste the JSON key into chat, source control, a ConfigMap, or the sandbox filesystem. Keep it on the Mac and provide it to the OpenShell gateway through the CLI.

# 4. Install the Agent Sandbox controller

1. Install the CRD and controller

```bash
oc apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v0.5.5/sandbox-with-extensions.yaml
```

2. Verify readiness

```bash
oc get crd sandboxes.agents.x-k8s.io
oc -n agent-sandbox-system get pods
```

# 5. Install OpenShell on OpenShift

1. Create the namespace

```bash
oc create namespace openshell-test
```

2. Install the Helm release with OpenShift overrides

```bash
helm upgrade --install openshell-test \
  oci://ghcr.io/nvidia/openshell/helm-chart \
  --version 0.0.98 \
  --namespace openshell-test \
  --set server.disableTls=true \
  --set server.auth.allowUnauthenticatedUsers=true \
  --set podSecurityContext.fsGroup=null \
  --set securityContext.runAsUser=null
```

> **WHY THE RELEASE NAME MATTERS** — Using openshell-test avoids taking ownership of cluster-scoped RBAC resources belonging to another OpenShell Helm release.

3. Grant the privileged SCC to the generated sandbox service account

```bash
oc adm policy add-scc-to-user privileged \
  -z openshell-test-sandbox \
  -n openshell-test
```

4. Verify the deployed resources

```bash
oc -n openshell-test get pods,svc,sa
oc -n openshell-test rollout status statefulset/openshell-test
```

# 6. Install and connect the OpenShell CLI

1. Install the OpenShell CLI on the Mac

```bash
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | \
  OPENSHELL_VERSION=v0.0.98 sh
openshell --version
```

2. Start the gateway port-forward and leave it running

```bash
oc -n openshell-test port-forward service/openshell-test 8080:8080
```

3. In another terminal, register the endpoint once

```bash
openshell gateway add http://127.0.0.1:8080 \
  --local \
  --name dylan-hermes
openshell status
```

> **EXPECTED** — Status should be Connected. A connection-refused error means the foreground oc port-forward ended; restart it. Do not add the gateway again if the name already exists.

# 7. Create and verify the base sandbox

```bash
openshell sandbox create --name test-sandbox --from base
openshell sandbox list
oc -n openshell-test get sandboxes.agents.x-k8s.io,pods -w
```

When the sandbox is ready:

```bash
openshell sandbox connect test-sandbox
```

