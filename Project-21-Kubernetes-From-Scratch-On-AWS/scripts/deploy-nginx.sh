#!/bin/bash

kubectl run nginx --image=nginx
kubectl expose pod nginx --port=80 --type=NodePort
