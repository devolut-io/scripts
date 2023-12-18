#!/bin/bash

aws iam create-user --user-name devolut-ro
aws iam attach-user-policy --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess --user-name devolut-ro
aws iam create-access-key --user-name devolut-ro
