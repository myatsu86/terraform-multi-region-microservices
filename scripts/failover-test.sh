#!/bin/bash
# Failover test: terminates one ASG instance and verifies the ALB keeps serving

ASG_NAME="${1:-customer-profile-svc-asg}"
ENDPOINT="https://retail-banking.myatsumon.info"
REGION="eu-central-1"
POLL_INTERVAL=2   # seconds between health checks
WATCH_DURATION=120 # seconds to watch after termination

echo "======================================"
echo " Failover Test"
echo "======================================"
echo " ASG:      $ASG_NAME"
echo " Endpoint: $ENDPOINT"
echo " Region:   $REGION"
echo "======================================"
echo ""

# --- Step 1: verify endpoint is healthy before starting ---
echo "[PRE-CHECK] Checking endpoint..."
status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ENDPOINT")
if [ "$status" != "200" ]; then
  echo "[PRE-CHECK] FAIL - endpoint returned HTTP $status. Aborting."
  exit 1
fi
echo "[PRE-CHECK] OK (HTTP $status)"
echo ""

# --- Step 2: start continuous polling in background ---
PASS=0
FAIL=0
POLL_LOG=$(mktemp)

(
  while true; do
    ts=$(date +"%H:%M:%S")
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ENDPOINT" 2>/dev/null)
    if [ "$code" = "200" ]; then
      echo "[$ts] OK   (HTTP $code)"
    else
      echo "[$ts] FAIL (HTTP $code)"
    fi
    sleep "$POLL_INTERVAL"
  done
) | tee "$POLL_LOG" &
POLL_PID=$!

echo "Polling started (PID $POLL_PID). Waiting 5s before terminating instance..."
sleep 5

# --- Step 3: pick and terminate one instance ---
echo ""
echo "--- ASG instances BEFORE termination ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$REGION" \
  --query "AutoScalingGroups[0].Instances[*].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}" \
  --output table

INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$REGION" \
  --query "AutoScalingGroups[0].Instances[0].InstanceId" \
  --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "ERROR: No instances found in ASG $ASG_NAME"
  kill $POLL_PID 2>/dev/null
  exit 1
fi

echo ""
echo "Terminating instance: $INSTANCE_ID"
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --output table

echo ""
echo "--- Watching ASG replace the instance (${WATCH_DURATION}s) ---"

elapsed=0
while [ $elapsed -lt $WATCH_DURATION ]; do
  sleep 10
  elapsed=$((elapsed + 10))
  echo ""
  echo "[+${elapsed}s] ASG instance status:"
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query "AutoScalingGroups[0].Instances[*].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}" \
    --output table
done

# --- Step 4: stop polling and print summary ---
kill $POLL_PID 2>/dev/null
wait $POLL_PID 2>/dev/null

echo ""
echo "======================================"
echo " Result Summary"
echo "======================================"
PASS=$(grep -c " OK " "$POLL_LOG" 2>/dev/null || echo 0)
FAIL=$(grep -c " FAIL " "$POLL_LOG" 2>/dev/null || echo 0)
TOTAL=$((PASS + FAIL))
echo " Total requests : $TOTAL"
echo " Successful     : $PASS"
echo " Failed         : $FAIL"
echo "======================================"

rm -f "$POLL_LOG"
