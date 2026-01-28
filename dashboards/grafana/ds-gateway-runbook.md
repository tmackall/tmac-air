# DS Gateway API - Runbook

## Overview

| **Service** | DS Gateway (service-datasciencegateway) |
|-------------|----------------------------------------|
| **Team** | AI Tech Platform |
| **Dashboard** | [DS Gateway API - Unified Observability](https://ukg.grafana.net/d/ds-gateway-api-observability-v2) |
| **Slack Channel** | #ai-tech-platform-alerts |
| **PagerDuty Service** | NOC - DS Gateway (TBD) |

---

## Alerts

| Alert | Severity | Threshold | Duration |
|-------|----------|-----------|----------|
| High Error Rate | P1 Critical | > 15% (4xx + 5xx) | 15 min |
| Response Time Degradation | P2 Warning | P95 > 5 seconds | 15 min |
| JVM Memory Pressure | P2 Warning | Heap > 85% | 15 min |

---

## P1: High Error Rate (> 15%)

### What It Means
The combined rate of 4xx (client errors) and 5xx (server errors) has exceeded 15% of total traffic for at least 15 minutes. This indicates significant service degradation affecting users.

### Immediate Actions

1. **Check the dashboard**
   - Open [DS Gateway Dashboard](https://ukg.grafana.net/d/ds-gateway-api-observability-v2)
   - Look at "5xx Error Rate by URI" panel to identify affected endpoints
   - Check "4xx Error Rate by URI" panel for client error patterns

2. **Identify the error type**
   - **5xx errors** = Server-side issue (investigate gateway/downstream services)
   - **4xx errors** = Client-side issue (check for bad deployments, API changes, auth issues)

3. **Check recent deployments**
   - Were there any recent deployments to the gateway or downstream services?
   - Consider rollback if errors correlate with deployment time

4. **Check downstream dependencies**
   - Are downstream AI services healthy? (Skills, Agents, etc.)
   - Check dependent service dashboards for errors

### Investigation Commands

```bash
# Check gateway pod logs for errors
kubectl logs -n ds-prod -l app=service-datasciencegateway --tail=500 | grep -i error

# Check pod status
kubectl get pods -n ds-prod -l app=service-datasciencegateway

# Check recent events
kubectl get events -n ds-prod --sort-by='.lastTimestamp' | grep gateway
```

### Common Causes

| Cause | Symptoms | Resolution |
|-------|----------|------------|
| Downstream service outage | 5xx errors, specific URIs affected | Check downstream service health, wait for recovery or failover |
| Bad deployment | Errors started after deployment | Rollback deployment |
| Authentication issues | 401/403 errors spike | Check token validation service, IAM configuration |
| Resource exhaustion | 503 errors, high latency | Scale pods, check resource limits |
| Database/cache issues | Timeouts, 5xx errors | Check database connections, Redis health |

### Escalation
- If errors persist after 30 minutes, escalate to AI Tech Platform on-call
- If downstream services are the root cause, engage the owning team

---

## P2: Response Time Degradation (P95 > 5s)

### What It Means
The estimated 95th percentile response time has exceeded 5 seconds for at least 15 minutes. Users are experiencing slow responses.

**Note:** P95 is estimated as average response time × 2 due to histogram bucket cardinality constraints.

### Immediate Actions

1. **Check the dashboard**
   - Open [DS Gateway Dashboard](https://ukg.grafana.net/d/ds-gateway-api-observability-v2)
   - Look at "Top 10 End-to-End Latency by URI" to identify slow endpoints
   - Check "Response Time Trend" for when degradation started

2. **Identify slow endpoints**
   - Which URIs have the highest latency?
   - Is it all endpoints or specific ones?

3. **Check resource utilization**
   - CPU usage on gateway pods
   - Memory usage / GC pressure
   - Network latency to downstream services

### Investigation Commands

```bash
# Check pod resource usage
kubectl top pods -n ds-prod -l app=service-datasciencegateway

# Check for GC pressure in logs
kubectl logs -n ds-prod -l app=service-datasciencegateway --tail=500 | grep -i "gc\|garbage"

# Check pod restarts (may indicate OOM)
kubectl get pods -n ds-prod -l app=service-datasciencegateway -o wide
```

### Common Causes

| Cause | Symptoms | Resolution |
|-------|----------|------------|
| Downstream service slow | Specific URIs affected | Investigate downstream service |
| High traffic volume | All endpoints slow, high RPS | Scale pods horizontally |
| JVM GC pressure | Spiky latency, high heap usage | Increase heap, investigate memory leaks |
| CPU throttling | High CPU %, request queuing | Increase CPU limits, scale pods |
| Network issues | All external calls slow | Check network path, DNS resolution |
| Database slow queries | Endpoints with DB calls affected | Check query performance, indexes |

### Escalation
- If latency persists and affects users, notify AI Tech Platform team
- If caused by downstream service, engage owning team

---

## P2: JVM Memory Pressure (> 85%)

### What It Means
The JVM heap memory usage has exceeded 85% for at least 15 minutes. This may lead to:
- Increased garbage collection (GC) pauses
- Degraded response times
- OutOfMemoryError (OOM) crashes

### Immediate Actions

1. **Check the dashboard**
   - Open [DS Gateway Dashboard](https://ukg.grafana.net/d/ds-gateway-api-observability-v2)
   - Look at "JVM Heap Memory Usage Over Time" panel
   - Check if memory is steadily climbing (leak) or spiking (load-related)

2. **Check for OOM kills**
   - Have any pods restarted recently?
   - Check Kubernetes events for OOMKilled

3. **Assess immediate risk**
   - Is memory still climbing or stable at 85-90%?
   - Are there GC pauses affecting latency?

### Investigation Commands

```bash
# Check pod restarts and status
kubectl get pods -n ds-prod -l app=service-datasciencegateway -o wide

# Check for OOMKilled events
kubectl get events -n ds-prod --sort-by='.lastTimestamp' | grep -i oom

# Check memory usage
kubectl top pods -n ds-prod -l app=service-datasciencegateway

# Get heap dump (if needed for analysis)
kubectl exec -n ds-prod <pod-name> -- jcmd 1 GC.heap_dump /tmp/heapdump.hprof
```

### Common Causes

| Cause | Symptoms | Resolution |
|-------|----------|------------|
| Memory leak | Steady increase over hours/days | Identify leak, deploy fix, restart pods |
| Insufficient heap | High usage under normal load | Increase heap size in deployment |
| Traffic spike | Memory spike correlates with RPS | Scale pods, let traffic normalize |
| Large request payloads | Memory spikes on specific endpoints | Investigate payload sizes, add limits |
| Caching issues | Unbounded cache growth | Review cache configuration, add eviction |

### Short-term Mitigation

```bash
# Restart a pod to clear memory (rolling restart)
kubectl rollout restart deployment/service-datasciencegateway -n ds-prod

# Scale up to distribute load
kubectl scale deployment/service-datasciencegateway -n ds-prod --replicas=<N+1>
```

### Escalation
- If memory continues to climb toward 95%+, consider preemptive pod restarts
- If this is a recurring issue, create a ticket to investigate root cause

---

## Useful Links

| Resource | Link |
|----------|------|
| Dashboard | [DS Gateway API - Unified Observability](https://ukg.grafana.net/d/ds-gateway-api-observability-v2) |
| K8s Cluster Health | [K8s Cluster Health Dashboard](https://ukg.grafana.net/d/0VSiotDnk/k8s-cluster-health) |
| Grafana Alerting | [Grafana Alert Rules](https://ukg.grafana.net/alerting/list) |
| Source Code | TBD |
| Architecture Docs | TBD |

---

## Contacts

| Role | Contact |
|------|---------|
| AI Tech Platform Team | #ai-tech-platform (Slack) |
| On-Call | PagerDuty - NOC DS Gateway |
| Service Owner | TBD |

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-21 | Tom Mackall | Initial version |
