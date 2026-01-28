# LLM Passthrough Service Dashboard - Summary of Required Actions

**Document Version:** 1.0  
**Date:** January 23, 2026  
**JIRA Ticket:** PS-687953  
**Dashboard UID:** `llm-passthrough-unified-observability`

---

## 📊 Executive Summary

This document provides a gap analysis between the project requirements and the current implementation of the LLM Passthrough Service Observability Dashboard. It outlines completed work, identified gaps, and required actions to achieve full acceptance criteria compliance.

---

## ✅ Completed Implementation

### Dashboard Panels

| Category | Status | Panels Implemented |
|----------|--------|-------------------|
| **Success Rate Metrics** | ✅ Complete | HTTP Success Rate, 5xx Error Rate, 4xx Error Rate, Combined Error Rate, Success & Error Rate Trend |
| **Usage & Request Patterns** | ✅ Complete | Current RPS, Total Requests, Requests by Endpoint, Requests by Status, Endpoint Distribution |
| **Latency Behavior** | ✅ Complete | Average Latency, P50/P90/P95/P99 Latency, Latency Percentiles Over Time, Latency by Substream ID |
| **Tenant-Level Metrics** | ⚠️ Partial | Panels exist but require `product_id` label instrumentation |
| **Business Usage Metrics** | ⚠️ Partial | LLM API Calls complete; Token metrics require Arize integration |
| **Infrastructure Health** | ✅ Complete | Deployment Status, CPU Usage, Memory Usage |
| **Alerting Status** | ✅ Complete | Visual alert indicators for Error Rate and Response Time |

### Dashboard Filters

| Filter | Status | Configuration |
|--------|--------|---------------|
| **Datasource** | ✅ Complete | Regex: `/^[Uu][Kk][Gg]/` (dev/prod) |
| **Datacenter (Region)** | ✅ Complete | All regions with `includeAll: true` |
| **Namespace** | ✅ Complete | Regex: `/^ds-.*/` |
| **Product ID** | ✅ Complete | Multi-select with `includeAll: true` |
| **Interval** | ✅ Complete | Auto with manual options (1m, 5m, 10m, 30m, 1h) |

---

## ❌ Identified Gaps

### 1. Grafana Alert Rules (YAML Provisioning)

| Gap | Priority | Status |
|-----|----------|--------|
| High Error Rate Alert (5xx > 15% for 15m) | 🔴 Critical | ✅ **CREATED** - `ds_llm_passthrough_alerting_rules.yml` |
| Response Time Degradation Alert (P95 > 10s for 15m) | 🟠 Warning | ✅ **CREATED** - `ds_llm_passthrough_alerting_rules.yml` |
| PagerDuty/Slack Contact Points | 🔴 Critical | ⏳ Requires configuration with actual credentials |

### 2. Token Count Metrics (Business Usage)

| Gap | Impact | Resolution |
|-----|--------|------------|
| `llm_token_count_total` metric not instrumented | Token tracking unavailable | Use Arize for token/cost metrics |
| Total Token Count panel shows 0 | Business metrics incomplete | Arize integration required |
| Average Tokens per Call cannot calculate | Cost analysis limited | Arize integration required |

### 3. Tenant-Level Metrics (`product_id` Label)

| Gap | Impact | Resolution |
|-----|--------|------------|
| `product_id` not on `http_request_count_total` | Cannot filter by tenant | Request instrumentation from app team |
| `product_id` not on latency metrics | Cannot measure tenant latency | Request instrumentation from app team |
| Tenant panels show no data | Tenant isolation monitoring unavailable | Using `substream_id` as workaround |

### 4. Additional Dashboard Gaps

| Gap | Priority | Resolution |
|-----|----------|------------|
| Arize Dashboard URL empty | 🟡 Low | Add actual Arize dashboard URL |
| Latency by endpoint not available | 🟡 Medium | Requires `endpoint` label on latency metrics |
| Cost of models tracking | 🟡 Medium | Arize only - not in Prometheus |

---

## 📋 Required Actions

### Immediate Actions (High Priority)

| # | Action | Owner | Effort | Status |
|---|--------|-------|--------|--------|
| 1 | **Deploy alerting rules YAML file** | Platform Team | Low | ⏳ Ready to deploy |
| 2 | **Configure PagerDuty routing key** | Platform Team | Low | ⏳ Pending |
| 3 | **Configure Slack webhook URL** | Platform Team | Low | ⏳ Pending |
| 4 | **Create SOPs for each alert** | Platform Team | Medium | ⏳ Pending |

### External Dependencies (Requires Other Teams)

| # | Action | Owner | Effort | Status |
|---|--------|-------|--------|--------|
| 5 | **Add `product_id` label to `http_request_count_total`** | App Team | Medium | ⏳ Request needed |
| 6 | **Add `product_id` label to latency histogram metrics** | App Team | Medium | ⏳ Request needed |
| 7 | **Add `endpoint` label to latency metrics** | App Team | Medium | ⏳ Request needed |
| 8 | **Instrument `llm_token_count_total` metric** | App Team | High | ⏳ Request needed |

### Optional Enhancements

| # | Action | Owner | Effort | Status |
|---|--------|-------|--------|--------|
| 9 | **Add Arize dashboard URL to dashboard link** | Platform Team | Low | ⏳ Pending |
| 10 | **Add latency by endpoint panels** (when label available) | Platform Team | Low | ⏳ Blocked |
| 11 | **Create Arize integration for token metrics** | Platform Team | Medium | ⏳ Pending |

---

## 🚨 Alerting Rules Summary

The following alerts have been created in `ds_llm_passthrough_alerting_rules.yml`:

### Critical Alerts (P1)

| Alert Name | Condition | Duration | Layer |
|------------|-----------|----------|-------|
| Metrics endpoint not scraped | `up < 1` | 30m | L0 |
| Deployment replicas below spec | Available < 50% | 20m | L1 |
| High Container Restarts | >= 4 restarts in 15m | 15m | L1 |
| **High 5xx Error Rate** ⭐ | 5xx rate > 15% | 15m | L3 |

### Warning Alerts (P2)

| Alert Name | Condition | Duration | Layer |
|------------|-----------|----------|-------|
| High Container CPU Usage | CPU >= 75 millicores | 30m | L1 |
| High Container Memory Usage | Memory >= 95% | 30m | L1 |
| High Combined Error Rate | 4xx+5xx > 20% | 15m | L3 |
| HTTP Success Rate Below 85% | Success < 85% | 15m | L3 |
| **P95 Latency High** ⭐ | P95 > 10 seconds | 15m | L4 |
| P99 Latency Extremely High | P99 > 30 seconds | 15m | L4 |

### Info Alerts (P3)

| Alert Name | Condition | Duration | Layer |
|------------|-----------|----------|-------|
| Average Latency High | Avg > 15 seconds | 15m | L4 |
| Unexpectedly Low Traffic | Very low RPS during business hours | 30m | L5 |

⭐ = Required per acceptance criteria

---

## 📁 Deliverables

| File | Description | Status |
|------|-------------|--------|
| `ds-llm-passthrough-api-observability.json` | Grafana Dashboard JSON | ✅ Complete |
| `ds_llm_passthrough_alerting_rules.yml` | Grafana Alerting Rules YAML | ✅ Created |
| `LLM_Passthrough_Dashboard_Summary.md` | This summary document | ✅ Complete |

---

## 🔗 Related Links

| Resource | URL |
|----------|-----|
| JIRA Ticket | https://engjira.int.kronos.com/browse/PS-687953 |
| Technical Analysis | https://engconf.int.kronos.com/spaces/AI/pages/1063503700/Technical+Analysis+LLM+Service+Observability+Gaps |
| Dashboard (Prod) | https://ukg.grafana.net/d/llm-passthrough-unified-observability |
| Arize Dashboard | TBD - Add URL when available |

---

## 📝 Acceptance Criteria Checklist

From JIRA PS-687953:

- [x] Panels created for Success rate
- [x] Panels created for Usage and request patterns
- [x] Panels created for Latency behavior
- [x] Panels created for Tenant-level metrics (structure ready, awaiting instrumentation)
- [x] Panels created for Business usage metrics (partial - token metrics in Arize)
- [x] Use visualization for trending as needed
- [x] Filter: Datacenter (all regions)
- [x] Filter: namespace (ds-*)
- [x] Filter: datasource (dev/prod)
- [x] Filter: product_id
- [x] Create critical alert for High Error Rate (5xx > 15% for 15 minutes)
- [x] Create warning alert for Response Time Degradation (P95 > 10 sec for 15 minutes)
- [ ] Setup PagerDuty/Slack integration (configuration pending)

---

## 📅 Next Steps

1. **Week 1:** Deploy alerting rules and configure contact points
2. **Week 2:** Submit instrumentation requests to app team for `product_id` and token metrics
3. **Week 3:** Create SOPs for each alert
4. **Ongoing:** Monitor and tune alert thresholds based on production data

---

*Document maintained by: AIEng-FLL Team*
