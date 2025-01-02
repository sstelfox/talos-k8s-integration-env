# Kyverno Policy Notes

This directory contains the security and best practice policies applies to the cluster and the
specific applications, services, and workloads but is also responsible for some best practice sanity
checks in our CI/CD workflow.

The policies present in here have all been sourced either from the [official kyverno policies repository](https://github.com/kyverno/policies)
or have been generated specifically for this cluster.

## Policy Exceptions

Exceptions should not be made in the core policies themselves but should be tied to the deployed
version of the service and included as part of its deployment. This keeps the exceptions close to
the resources being permitted through our chosen policies.

* Each exception must be as narrow as possible at a minimum matching on the namespace, resource
  kind, and resource name.
* Each exception must include an description annotation indicating why the exception makes sense.
  These descriptions should be fully self-evident and not rely on internal/private knowledge. If
  there is a path to remove the exception, it should be included in the description.
* Exceptions must have an associated risk formally accepted

## Pre-Deployment Checks

Policies that live in the [pre-deployment](./pre-deployment) directory are exclusively checked
during the CI process and not injected into the cluster itself. These MUST only be for enforcing
best practices and should not be relied on for the security of resources.

The policies currently present have utility value, but not audit value and would likely consume
more resources than value they provide. Generated resources from operators will not be audited by
these policies, however, those resources are largely beyond individual control and would need to be
corrected upstream.
