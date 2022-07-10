#!/bin/bash

kustomize build . | kubectl delete -f -
