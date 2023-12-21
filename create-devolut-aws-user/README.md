# Create Devolut user
This script is used to create a read-only user on clients' AWS account, allowing us to quickly gain necessary permissions so we can start gathering info about a project.

## Usage
These steps are executed by someone from a clients' company.
```
export AWS_ACCESS_KEY_ID=<secret>
export AWS_SECRET_ACCESS_KEY=<secret>
export AWS_DEFAULT_REGION=<region>


wget https://raw.githubusercontent.com/devolut-io/scripts/master/create-devolut-aws-user/run.sh
bash run.sh
rm run.sh
```
