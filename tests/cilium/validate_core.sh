#!/usr/bin/env sh

if ! cilium status --wait; then
  echo "error: cilium never became sufficiently ready to begin the tests"
  exit 1
fi

kubectl apply -f tests/cilium/relaxed-cilium-test-psp.yaml

EXIT_CODE=0
if ! cilium connectivity test --hubble=false; then
  echo "error: connectivity test failed"
  EXIT_CODE=1
fi

if ! cilium connectivity test --perf --hubble=false; then
  echo "error: failed to perform performance test"
  EXIT_CODE=1
fi

# Note: right now this is unfortunately failing as it wants the NET_RAW capability which our PSS
# doesn't allow.
if ! cilium connectivity test --perf-crr --hubble=false; then
  echo "error: failed to perform performance test"
  EXIT_CODE=1
fi

# Ensure we clean up after ourselves
kubectl delete -f tests/cilium/relaxed-cilium-test-psp.yaml

# Our exit status should reflect the result of the tests
exit ${EXIT_CODE}
