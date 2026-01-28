# Arize LLM Metrics Query Guide

**Arize Space URL:** https://app.arize.com/organizations/QWNjb3VudE9yZ2FuaXphdGlvbjoxNDI5OTowWk91/spaces/U3BhY2U6MzAwNDA6NTNiOA==

---

## Prerequisites

Before you can query token metrics in Arize, the LLM Passthrough Service must be instrumented to send traces to Arize. This typically requires:

1. **OpenTelemetry instrumentation** using `openinference-instrumentation-openai` or similar
2. **Arize API key** configured in the service
3. **Token counts** being captured in spans (usually automatic with auto-instrumentation)

---

## Where to Find Metrics in Arize UI

### 1. Pre-Built Metrics Dashboard

Navigate to your project in Arize. The default metrics dashboard includes:

- **Trace latency and errors**
- **Latency Quantiles**
- **Cost over Time by token type**
- **Top Models by Cost**
- **Token Usage by token type**
- **Top Models by Tokens**
- **LLM Invocation and Errors**

### 2. Tracing Table

In the tracing view, you can see token counts aggregated per trace:
- Sort by token count to find long-running traces
- Filter traces by token count thresholds

---

## Custom Metrics Queries (ArizeQL)

Arize uses a SQL-like query language called **ArizeQL** for custom metrics. Here are example queries for LLM metrics:

### Token Count Queries

```sql
-- Total prompt tokens
SELECT SUM("attributes.llm.token_count.prompt") FROM model

-- Total completion tokens  
SELECT SUM("attributes.llm.token_count.completion") FROM model

-- Total tokens (prompt + completion)
SELECT SUM("attributes.llm.token_count.prompt" + "attributes.llm.token_count.completion") FROM model

-- Average tokens per request
SELECT AVG("attributes.llm.token_count.prompt" + "attributes.llm.token_count.completion") FROM model
```

### Cost Calculation Queries

```sql
-- Basic cost calculation (adjust pricing per your model)
SELECT SUM(
  "attributes.llm.token_count.completion" * 0.0001 + 
  "attributes.llm.token_count.prompt" * 0.0000025
) FROM model

-- Cost with per-million-token pricing (example: GPT-4 pricing)
SELECT SUM(
  "attributes.llm.token_count.completion" * 10 / 1000000 + 
  "attributes.llm.token_count.prompt" * 2.5 / 1000000
) FROM model

-- Combined cost with fixed prompt overhead
SELECT (
  SUM(
    "attributes.llm.token_count.prompt" + 
    "attributes.llm.token_count.completion" + 
    229  -- fixed prompt token length
  ) * 0.00000025
) + (COUNT(*) * (104 * 0.00001))  -- estimated output cost
FROM model
```

### Filtering by Attributes

```sql
-- Token count filtered by specific model
SELECT SUM("attributes.llm.token_count.prompt") 
FROM model 
WHERE "attributes.llm.model_name" = 'gpt-4'

-- Cost by tenant/product (if instrumented)
SELECT SUM("attributes.llm.token_count.completion" * 0.0001) 
FROM model 
WHERE "attributes.product_id" = 'tenant-abc'
```

---

## Creating a Custom Dashboard in Arize

### Step 1: Navigate to Dashboards
1. Go to your Arize space
2. Click **Dashboards** in the left navigation
3. Click **Create Dashboard** or use the default LLM template

### Step 2: Add Widgets

| Widget Type | Use Case |
|-------------|----------|
| **Timeseries** | Token usage over time, cost trends |
| **Statistic** | Total tokens, total cost, average latency |
| **Distribution** | Token usage by user, by model |
| **Table** | Top traces by token count |

### Step 3: Example Dashboard Widgets

**Widget 1: Total Token Count (Stat)**
```sql
SELECT SUM("attributes.llm.token_count.prompt" + "attributes.llm.token_count.completion") FROM model
```

**Widget 2: Token Usage Over Time (Timeseries)**
```sql
SELECT SUM("attributes.llm.token_count.prompt") as "Prompt Tokens",
       SUM("attributes.llm.token_count.completion") as "Completion Tokens"
FROM model
```

**Widget 3: Cost Over Time (Timeseries)**
```sql
SELECT SUM("attributes.llm.token_count.completion" * 0.06 / 1000 + 
           "attributes.llm.token_count.prompt" * 0.03 / 1000) as "Total Cost ($)"
FROM model
```

**Widget 4: Top Traces by Token Count (Table)**
- Use the built-in tracing table
- Sort by token count descending

---

## Setting Up Monitors/Alerts in Arize

Arize supports alerting via PagerDuty, Slack, and OpsGenie.

### Create a Token Cost Monitor

1. Go to **Monitors** in left navigation
2. Click **Create Monitor**
3. Select **Custom Metric** type
4. Enter query:
   ```sql
   SELECT SUM("attributes.llm.token_count.completion" * 0.0001) FROM model
   ```
5. Set threshold (e.g., > $100 per hour)
6. Configure notification channel

### Create a High Token Usage Monitor

1. Create monitor with query:
   ```sql
   SELECT AVG("attributes.llm.token_count.prompt" + "attributes.llm.token_count.completion") FROM model
   ```
2. Set threshold (e.g., > 10000 tokens average)
3. This helps detect runaway prompts or context overflow

---

## Key Token Attributes in Arize

| Attribute | Description |
|-----------|-------------|
| `attributes.llm.token_count.prompt` | Input/prompt token count |
| `attributes.llm.token_count.completion` | Output/completion token count |
| `attributes.llm.model_name` | Model used (e.g., gpt-4, claude-3) |
| `attributes.llm.provider` | Provider (OpenAI, Anthropic, etc.) |
| `latency_ms` | Request latency in milliseconds |

---

## Cost Tracking Configuration

Arize has built-in pricing for 63+ models. To configure custom pricing:

1. Go to **Settings > Models**
2. Create custom cost configuration
3. Set per-token costs for:
   - Prompt tokens
   - Completion tokens
   - Audio tokens (if applicable)
   - Image tokens (if applicable)

---

## Integration with Grafana (Optional)

If you want to display Arize metrics in Grafana alongside Prometheus metrics:

1. Use the **Grafana Infinity Plugin** to query Arize API
2. Or export Arize data and ingest into Prometheus
3. This allows unified dashboards with both operational (Prometheus) and business (Arize) metrics

---

## Next Steps

1. **Verify instrumentation**: Check if LLM Passthrough Service is sending traces to Arize
2. **Explore existing data**: Look at the tracing table for your space
3. **Create custom dashboard**: Build widgets for token count and cost
4. **Set up monitors**: Configure alerts for cost thresholds
5. **Document Arize dashboard URL**: Add link to Grafana dashboard for cross-reference

---

## Useful Links

- [Arize Token Tracking Docs](https://docs.arize.com/arize/observe/dashboards/token-counting)
- [Arize Cost Tracking Docs](https://arize.com/docs/ax/observe/cost-tracking)
- [Arize Custom Metrics Examples](https://docs.arize.com/arize/observe/custom-metrics-api/custom-metric-examples)
- [Arize Dashboard Docs](https://arize.com/docs/ax/observe/dashboards)
- [Arize Monitors/Alerting](https://docs.arize.com/arize/observe/production-monitoring)

---

*Created: January 23, 2026*
