# DS Gateway Alert SOPs

This document contains Standard Operating Procedures for the DS Gateway alerting rules.
Create each SOP as a separate Confluence page using the team's SOP template.

---

## SOP 1: P1 : Flex : AI : DS Gateway : High Error Rate

| **Layered Observability** | Alert and SOP Standards and Templates, Observability Guidelines |
|---------------------------|----------------------------------------------------------------|
| **Candidate for Automation** | No |
| **Handoff to Responder** | Service |

### Ownership

| Role | Name/Contact |
|------|--------------|
| **Service Name** | ☑ L0 |
| **Service Team Contact** | AI Tech Platform |
| **SRE Manager** | TBD |
| **SRE Contact** | TBD |
| **SRE Team DL** | TBD |
| **Responder** | Service |
| **Approval** | Pending |

### Alert Details

| Field | Value |
|-------|-------|
| **Data Source** | Grafana (UKG Pro) |
| **What issue does this alert detect?** | This alert detects when the combined HTTP 4xx and 5xx error rate exceeds 15% for 15 minutes on the DS Gateway API. |
| **Describe the Customer Impact** | Users may experience failed API requests to AI services (Skills, Agents, RAG, etc.) routed through the gateway. This could result in failed operations, error messages, or degraded functionality in dependent applications. |
| **Monitored Metric and Threshold** | `(sum(rate(http_server_requests_seconds_count{namespace=~"ds-(prod\|sales.*)", application="gateway", status=~"[45].."}[5m])) / sum(rate(http_server_requests_seconds_count{namespace=~"ds-(prod\|sales.*)", application="gateway"}[5m]))) * 100 > 15` |
| **Plan for Full or Partial Automation** | No current automation planned. Root cause typically requires manual investigation of error patterns, downstream service health, and recent deployments. |

### Runbook/Remediation

| Step | Action |
|------|--------|
| **Step 1** | Open the [DS Gateway Dashboard](https://ukg.grafana.net/d/ds-gateway-api-observability-v2) and identify the error pattern. Check "5xx Error Rate by URI" and "4xx Error Rate by URI" panels to identify affected endpoints. |
| **Step 2** | Determine error type: **5xx errors** indicate server-side issues (gateway or downstream). **4xx errors** indicate client-side issues (auth, bad requests, API misuse). |
| **Step 3** | Check recent deployments. Were there any deployments to the gateway or downstream services in the last hour? Consider rollback if errors correlate with deployment time. |
| **Step 4** | Check downstream service health. Are dependent AI services (Skills, Agents, RAG) healthy? Check their dashboards for errors. |
| **Step 5** | Check gateway pod logs for errors: `kubectl logs -n ds-prod -l app=service-datasciencegateway --tail=500 \| grep -i error` |
| **Step 6** | Check pod status and recent events: `kubectl get pods -n ds-prod -l app=service-datasciencegateway` and `kubectl get events -n ds-prod --sort-by='.lastTimestamp' \| grep gateway` |
| **Step 7** | If 5xx errors and no obvious cause, check resource utilization (CPU, memory) and consider scaling or restarting pods. |
| **Step 8** | Document findings and root cause in incident ticket. |

### Verification

| Step | Action |
|------|--------|
| **Step 1** | Confirm error rate has dropped below 15% on the dashboard. |
| **Step 2** | Verify gateway pods are running: `kubectl get pods -n ds-prod -l app=service-datasciencegateway \| grep Running` should show all pods in Running state. |
| **Step 3** | Test the health endpoint to ensure service is operational: `curl https://<gateway-url>/health` |

### Escalation

| Condition | Action |
|-----------|--------|
| **If the issue persists** | 1. Page AI Tech Platform on-call via PagerDuty. 2. If no response in 10 minutes, initiate a P1 bridge. 3. Include: Environment/datacenter affected, Error types and affected URIs, Steps followed so far, Duration of issue and impact scope. |

### Improvement

NOC will create a Jira ticket for any improvement request and assign it to the AI Tech Platform team for review.

---

## SOP 2: P2 : Flex : AI : DS Gateway : Response Time Degradation

| **Layered Observability** | Alert and SOP Standards and Templates, Observability Guidelines |
|---------------------------|----------------------------------------------------------------|
| **Candidate for Automation** | No |
| **Handoff to Responder** | Service |

### Ownership

| Role | Name/Contact |
|------|--------------|
| **Service Name** | ☑ L0 |
| **Service Team Contact** | AI Tech Platform |
| **SRE Manager** | TBD |
| **SRE Contact** | TBD |
| **SRE Team DL** | TBD |
| **Responder** | Service |
| **Approval** | Pending |

### Alert Details

| Field | Value |
|-------|-------|
| **Data Source** | Grafana (UKG Pro) |
| **What issue does this alert detect?** | This alert detects when the estimated P95 response time (calculated as average × 2) exceeds 5 seconds for 15 minutes on the DS Gateway API. |
| **Describe the Customer Impact** | Users may experience slow response times when using AI services routed through the gateway. This could result in timeouts, poor user experience, or cascading delays in dependent applications. |
| **Monitored Metric and Threshold** | `((sum(rate(http_server_requests_seconds_sum{namespace=~"ds-(prod\|sales.*)", application="gateway"}[5m])) / sum(rate(http_server_requests_seconds_count{namespace=~"ds-(prod\|sales.*)", application="gateway"}[5m]))) * 2) > 5` |
| **Plan for Full or Partial Automation** | No current automation planned. Root cause typically requires manual investigation of slow endpoints, downstream latency, and resource utilization. |

### Runbook/Remediation

| Step | Action |
|------|--------|
| **Step 1** | Open the [DS Gateway Dashboard](https://ukg.grafana.net/d/ds-gateway-api-observability-v2) and check "Top 10 End-to-End Latency by URI" to identify slow endpoints. |
| **Step 2** | Check "Response Time Trend" panel to see when degradation started and correlate with any events (deployments, traffic spikes). |
| **Step 3** | Identify if latency is affecting all endpoints or specific ones. Specific endpoints may indicate downstream service issues. |
| **Step 4** | Check gateway resource utilization: `kubectl top pods -n ds-prod -l app=service-datasciencegateway` |
| **Step 5** | Check for GC pressure in logs: `kubectl logs -n ds-prod -l app=service-datasciencegateway --tail=500 \| grep -i "gc\|garbage"` |
| **Step 6** | Check downstream service latency. Are dependent AI services responding slowly? |
| **Step 7** | If resource-related, consider scaling pods horizontally: `kubectl scale deployment/service-datasciencegateway -n ds-prod --replicas=<N+1>` |
| **Step 8** | Document findings and root cause in incident ticket. |

### Verification

| Step | Action |
|------|--------|
| **Step 1** | Confirm P95 latency estimate has dropped below 5 seconds on the dashboard. |
| **Step 2** | Verify response times for key endpoints are acceptable. |
| **Step 3** | Test the health endpoint response time: `time curl https://<gateway-url>/health` |

### Escalation

| Condition | Action |
|-----------|--------|
| **If the issue persists** | 1. Page AI Tech Platform on-call via PagerDuty. 2. Include: Environment/datacenter affected, Slow endpoints identified, Resource utilization metrics, Steps followed so far. |

### Improvement

NOC will create a Jira ticket for any improvement request and assign it to the AI Tech Platform team for review.

---

## SOP 3: P2 : Flex : AI : DS Gateway : JVM Memory Pressure

| **Layered Observability** | Alert and SOP Standards and Templates, Observability Guidelines |
|---------------------------|----------------------------------------------------------------|
| **Candidate for Automation** | No |
| **Handoff to Responder** | Service |

### Ownership

| Role | Name/Contact |
|------|--------------|
| **Service Name** | ☑ L0 |
| **Service Team Contact** | AI Tech Platform |
| **SRE Manager** | TBD |
| **SRE Contact** | TBD |
| **SRE Team DL** | TBD |
| **Responder** | Service |
| **Approval** | Pending |

### Alert Details

| Field | Value |
|-------|-------|
| **Data Source** | Grafana (UKG Pro) |
| **What issue does this alert detect?** | This alert detects when the JVM heap memory usage exceeds 85% for 15 minutes on the DS Gateway API pods. |
| **Describe the Customer Impact** | High memory pressure may lead to increased garbage collection pauses, degraded response times, or OutOfMemoryError crashes. If pods crash, users may experience failed requests until pods recover. |
| **Monitored Metric and Threshold** | `avg((jvm_memory_used_bytes{namespace=~"ds-(prod\|sales.*)", application="gateway", area="heap"} / jvm_memory_max_bytes{namespace=~"ds-(prod\|sales.*)", application="gateway", area="heap"}) and jvm_memory_max_bytes{...} > 0) * 100 > 85` |
| **Plan for Full or Partial Automation** | No current automation planned. Root cause typically requires manual investigation of memory patterns, potential leaks, and traffic analysis. |

### Runbook/Remediation

| Step | Action |
|------|--------|
| **Step 1** | Open the [DS Gateway Dashboard](https://ukg.grafana.net/d/ds-gateway-api-observability-v2) and check "JVM Heap Memory Usage Over Time" panel. |
| **Step 2** | Determine if memory is steadily climbing (potential leak) or spiking (load-related). Check correlation with traffic patterns. |
| **Step 3** | Check for OOM kills: `kubectl get events -n ds-prod --sort-by='.lastTimestamp' \| grep -i oom` |
| **Step 4** | Check pod restarts: `kubectl get pods -n ds-prod -l app=service-datasciencegateway -o wide` |
| **Step 5** | Check current memory usage: `kubectl top pods -n ds-prod -l app=service-datasciencegateway` |
| **Step 6** | If memory is above 90% and climbing, consider preemptive rolling restart: `kubectl rollout restart deployment/service-datasciencegateway -n ds-prod` |
| **Step 7** | If load-related, scale up to distribute load: `kubectl scale deployment/service-datasciencegateway -n ds-prod --replicas=<N+1>` |
| **Step 8** | If recurring, create ticket to investigate root cause (potential memory leak, insufficient heap size, unbounded caching). |

### Verification

| Step | Action |
|------|--------|
| **Step 1** | Confirm JVM heap usage has dropped below 85% on the dashboard. |
| **Step 2** | Verify no pods are in OOMKilled or CrashLoopBackOff state. |
| **Step 3** | Monitor memory trend for 15-30 minutes to ensure stability. |

### Escalation

| Condition | Action |
|-----------|--------|
| **If the issue persists** | 1. Page AI Tech Platform on-call via PagerDuty. 2. Include: Environment/datacenter affected, Memory trend (climbing vs stable), Pod restart count, Steps followed so far. |

### Improvement

NOC will create a Jira ticket for any improvement request and assign it to the AI Tech Platform team for review.
