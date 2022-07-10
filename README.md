# kustomize multi-base demo

## Summary

Build multiple daemonSets based from a single source daemonSet.
Apply the daemonSets to nodes dependant on the node labels.

# Requirements

This was done using kind and kustomize.

# TL;DR

This is the kustomize patch you want
```yaml
patchesJson6902:
- target:
    group: apps
    version: v1
    kind: DaemonSet
    # apply to ALL daemonsets in this patch
    name: ".*"
  # note the trailing '-' for array append in the path, and the missing starting '-' for the actual item in the value
  patch: |-
    # add our size selection
    - op: add
      path: /spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/0/matchExpressions/-
      value:
        key: size
        operator: In
        values:
        - small

    # remove the deprecated selection terms
    - op: remove
      path: /spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/1
```

# Process


Directory tree
```bash
$ tree
.
├── apply-ds.sh
├── base
│   ├── daemonset.yaml
│   └── kustomization.yaml
├── delete-ds.sh
├── kustomization.yaml
├── large
│   └── kustomization.yaml
├── medium
│   └── kustomization.yaml
├── multi-base-lab.yaml
├── README.md
├── small
│   └── kustomization.yaml
├── start-cluster.sh
└── stop-cluster.sh
```


Start the kind cluster - 1 control plane, 3 worker nodes
```bash
$ ./start-cluster.sh
```

Show the lables we have assigned
```bash
$ kubectl get node -L size
NAME                        STATUS   ROLES           AGE   VERSION   SIZE
multi-base1-control-plane   Ready    control-plane   78s   v1.24.0   
multi-base1-worker          Ready    <none>          45s   v1.24.0   small
multi-base1-worker2         Ready    <none>          45s   v1.24.0   medium
multi-base1-worker3         Ready    <none>          45s   v1.24.0   large
```

Apply the kustomize build

```bash
$ kustomize build . | kubectl apply -f -
daemonset.apps/large-base-ds created
daemonset.apps/medium-base-ds created
daemonset.apps/small-base-ds created
```

Verify the lables have been applied to each daemnSet
```bash
$ kubectl get ds --show-labels
NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE   LABELS
large-base-ds    1         1         1       1            1           <none>          51m   app=base-ds,dsSize=large
medium-base-ds   1         1         1       1            1           <none>          51m   app=base-ds,dsSize=medium
small-base-ds    1         1         1       1            1           <none>          51m   app=base-ds,dsSize=small
```

Verify the daemonSets have been applied only to each selected node 
```bash
$ kubectl get pods -owide
NAME                   READY   STATUS    RESTARTS   AGE   IP           NODE                  NOMINATED NODE   READINESS GATES
large-base-ds-r486f    1/1     Running   0          20s   10.244.1.5   multi-base1-worker3   <none>           <none>
medium-base-ds-bvlmc   1/1     Running   0          20s   10.244.2.5   multi-base1-worker2   <none>           <none>
small-base-ds-45w25    1/1     Running   0          20s   10.244.3.5   multi-base1-worker    <none>           <none>
```




I have been really impressed on how easy it was to get this working.

My next trick will be to roll this into skaffold and apply depending on the environment selected.
