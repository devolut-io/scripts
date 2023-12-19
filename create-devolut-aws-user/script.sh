#!/bin/bash

aws iam create-user --user-name devolut-ro
aws iam put-user-policy --user-name devolut-ro --policy-name DevolutReadOnlyPolicy --policy-document file://policies.json
aws iam create-access-key --user-name devolut-ro
