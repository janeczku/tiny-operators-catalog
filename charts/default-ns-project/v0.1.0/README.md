## Namespace default project operator

This charts deploys an instance of [shell-operator](https://github.com/flant/shell-operator) configured with a hook to automatically assign namespaces created directly in the Kubernetes API (e.g. using kubectl) to a user configurable Rancher project.

### How it works

1. Deploy the Helm app providing the ID of the project to which new namespaces should be assigned, e.g. "c-x4czm:p-5g4m2".

2. Create a new namespace with kubectl:

```
kubectl create ns foo
```

3. Check logs of the operator pod to see how the hook was fired.
4. Verify that the new namespace has been automatically assigned to the default project
