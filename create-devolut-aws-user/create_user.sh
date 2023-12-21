#!/bin/bash

USERNAME=devolut-ro

pwd

aws iam create-user --user-name $USERNAME
aws iam create-login-profile --user-name $USERNAME --password devolut@2024 --password-reset-required
aws iam put-user-policy --user-name $USERNAME --policy-name DevolutReadOnlyPolicy --policy-document file://policies/read_only_all.json
aws iam create-access-key --user-name $USERNAME
