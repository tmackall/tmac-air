# Metric Verification Queries for Grafana

Run these queries in **Grafana Explore** with your Prometheus datasource.
If the result is > 0, the metric exists and you can build dashboards without instrumentation work.

---

## Quick All-Services Check

### Find all Python services with HTTP metrics:
```promql
count by (name) (http_request_count_total{name=~"service-.*"})
```

### Find all Java services with HTTP metrics:
```promql
count by (application) (http_server_requests_seconds_count{application=~".*"})
```

---

## Python Services

### llm-service (REFERENCE - known to work)
```promql
# HTTP request count
count(http_request_count_total{name="service-large-language-model"})

# Latency histogram
count(request_incoming_duration_seconds_bucket{name="service-large-language-model"})

# Check available labels
group by (__name__, http_status, endpoint, namespace, datacenter) (http_request_count_total{name="service-large-language-model"})
```

### config-manager
```promql
# HTTP request count
count(http_request_count_total{name="service-config-manager"})

# Latency histogram
count(request_incoming_duration_seconds_bucket{name="service-config-manager"})
```

### model-feedback
```promql
# HTTP request count
count(http_request_count_total{name="service-model-feedback"})

# Latency histogram
count(request_incoming_duration_seconds_bucket{name="service-model-feedback"})
```

### open-telemetry-collector
```promql
# HTTP request count
count(http_request_count_total{name="service-open-telemetry-collector"})

# Latency histogram
count(request_incoming_duration_seconds_bucket{name="service-open-telemetry-collector"})
```

### otel-event-processor
```promql
# HTTP request count
count(http_request_count_total{name="service-otel-event-processor"})

# Latency histogram
count(request_incoming_duration_seconds_bucket{name="service-otel-event-processor"})
```

---

## Java Services

### datascience-gateway (REFERENCE - known to work)
```promql
# HTTP request count
count(http_server_requests_seconds_count{application="gateway"})

# Latency histogram
count(http_server_requests_seconds_bucket{application="gateway"})

# JVM Memory
count(jvm_memory_used_bytes{application="gateway"})

# Check available labels
group by (__name__, status, uri, namespace) (http_server_requests_seconds_count{application="gateway"})
```

### cmp-adapter
```promql
# HTTP request count
count(http_server_requests_seconds_count{application="service-cmp-adapter"})

# Latency histogram  
count(http_server_requests_seconds_bucket{application="service-cmp-adapter"})

# JVM Memory
count(jvm_memory_used_bytes{application="service-cmp-adapter"})
```

---

## Tenant Label Verification

Check if product_id label exists (required for tenant-level metrics):

```promql
# Python services
count(http_request_count_total{name="service-large-language-model", product_id!=""})

# Java services
count(http_server_requests_seconds_count{application="gateway", product_id!=""})
```

Check if substream_id label exists:
```promql
count(http_request_count_total{name="service-large-language-model", substream_id!=""})
```

---

## Infrastructure Metrics

These should exist for all services via Kubernetes metrics:

```promql
# Container CPU (replace with your service name pattern)
count(container_cpu_usage_seconds_total{pod=~"service-large-language-model.*"})

# Container Memory
count(container_memory_working_set_bytes{pod=~"service-large-language-model.*"})

# Deployment replicas
count(kube_deployment_status_replicas_available{deployment=~"service-large-language-model"})
```

---

## Interpreting Results

| Result | Meaning | Action |
|--------|---------|--------|
| **> 0** | Metric EXISTS | Build dashboard (quick win!) |
| **0 or error** | Metric does NOT exist | Needs instrumentation work |
| **Partial labels** | Some labels missing | May need to add labels |

---

## Service Name Mapping

If queries return 0, the Prometheus service name might be different. Try these variations:

| Service | Try these Prometheus names |
|---------|---------------------------|
| cmp-adapter | `service-cmp-adapter`, `cmp-adapter` |
| config-manager | `service-config-manager`, `config-manager` |
| datascience-gateway | `gateway`, `datascience-gateway`, `service-datascience-gateway` |
| model-feedback | `service-model-feedback`, `model-feedback` |
| llm-service | `service-large-language-model`, `llm-service` |
| otel-collector | `service-open-telemetry-collector`, `otel-collector` |
| otel-event-processor | `service-otel-event-processor`, `otel-event-processor` |

---

## Next Steps

1. Run the quick all-services check first
2. For services with metrics, record as "Likely Available" → Dashboard work only
3. For services without metrics, record as "Not Implemented" → Instrumentation needed
4. Bring results back and we'll update the assessment and generate Jira tasks
