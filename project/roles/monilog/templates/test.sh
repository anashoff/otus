curl -H "Content-Type: application/json" -d '[{
  "status": "firing",
  "labels": {
    "alertname": "InstanceDown",
    "instance": "192.168.1.50:9100",
    "job": "web",
    "severity": "critical"
  },
  "annotations": {
    "summary": "Instance  down",
    "description": "job node has been down for more than 30 seconds."
  },
  "generatorURL": "http://prometheus/local"
}]' http://localhost:9093/api/v2/alerts
