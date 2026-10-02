#!/bin/bash

set -e 

echo "Downloading fake-service..."
curl -LO https://github.com/nicholasjackson/fake-service/releases/download/v0.26.2/fake_service_linux_amd64.zip

echo "Unzipping fake-service..."
unzip fake_service_linux_amd64.zip

echo "Making binary executable..."
chmod +x fake-service

echo "Copying to Customer Profile instance ..."
scp fake-service profile-instance:/home/ubuntu/

echo "Copying to Account instance ..."
scp fake-service account-instance:/home/ubuntu/

echo "Copying to Statement instance ..."
scp fake-service statement-instance:/home/ubuntu/

rm -rf fake_service_linux_amd64.zip fake-service