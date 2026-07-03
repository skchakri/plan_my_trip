#!/usr/bin/env bash
#
# Provision AWS infrastructure for Wanderply (wanderply.com), modeled on the
# existing prof_vault / ownsites apps in account 727185666062, us-east-1.
#
# Creates BILLABLE, hard-to-reverse resources (~$30/mo): a t3.small EC2, a
# db.t3.micro RDS, an Elastic IP, plus ECR/S3/IAM/SG (near-free). REVIEW before
# running. Requires ADMIN AWS credentials (the prof-vault-deployer user is scoped
# and cannot create EC2/RDS/IAM). Idempotent-ish: re-running skips what exists.
#
# After it finishes it prints the Elastic IP + RDS endpoint and offers to patch
# config/deploy.yml. Then follow docs/ops/AWS_DEPLOY.md to `kamal setup`.
set -euo pipefail

REGION=us-east-1
ACCOUNT=727185666062
VPC=vpc-097b50785594e2b49              # shared VPC (same as prof-vault-app)
SUBNET=subnet-0fdfa755f730a2d97        # us-east-1a public subnet
DB_SUBNET_GROUP=prof-vault-db-subnet   # reused (already spans ≥2 AZs)
KEY_PATH=~/.ssh/wanderply-key.pem
APP=wanderply

echo "This will create billable AWS resources in $ACCOUNT/$REGION. Ctrl-C to abort."
read -rp "Type 'provision' to continue: " ok; [ "$ok" = provision ] || exit 1

aws sts get-caller-identity >/dev/null   # fail fast if creds are missing

# ── 1. ECR repository ────────────────────────────────────────────────────────
aws ecr describe-repositories --repository-names "$APP" --region "$REGION" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "$APP" --region "$REGION" >/dev/null
echo "✓ ECR repo $APP"

# ── 2. S3 bucket for Active Storage (private) ────────────────────────────────
if ! aws s3api head-bucket --bucket "$APP-storage" 2>/dev/null; then
  aws s3api create-bucket --bucket "$APP-storage" --region "$REGION" >/dev/null
  aws s3api put-public-access-block --bucket "$APP-storage" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi
echo "✓ S3 bucket $APP-storage"

# ── 3. IAM instance role (S3 + SES) ──────────────────────────────────────────
ROLE=$APP-ec2-role
if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE" --assume-role-policy-document '{
    "Version":"2012-10-17","Statement":[{"Effect":"Allow",
    "Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam put-role-policy --role-name "$ROLE" --policy-name "$APP-app" --policy-document "{
    \"Version\":\"2012-10-17\",\"Statement\":[
      {\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\",\"s3:DeleteObject\",\"s3:ListBucket\"],
       \"Resource\":[\"arn:aws:s3:::$APP-storage\",\"arn:aws:s3:::$APP-storage/*\"]},
      {\"Effect\":\"Allow\",\"Action\":[\"ses:SendEmail\",\"ses:SendRawEmail\"],\"Resource\":\"*\"}]}"
  aws iam create-instance-profile --instance-profile-name "$ROLE" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "$ROLE" --role-name "$ROLE"
  sleep 10   # let the instance profile propagate
fi
echo "✓ IAM role + instance profile $ROLE"

# ── 4. SSH key pair ──────────────────────────────────────────────────────────
if [ ! -f "$KEY_PATH" ]; then
  aws ec2 create-key-pair --key-name "$APP-key" --region "$REGION" \
    --query KeyMaterial --output text > "$KEY_PATH"
  chmod 400 "$KEY_PATH"
fi
echo "✓ key pair $APP-key → $KEY_PATH"

# ── 5. Security groups (app: 22/80/443, db: 5432 from app) ───────────────────
MYIP=$(curl -s https://checkip.amazonaws.com)/32
APP_SG=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=$APP-sg" "Name=vpc-id,Values=$VPC" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ "$APP_SG" = None ] || [ -z "$APP_SG" ]; then
  APP_SG=$(aws ec2 create-security-group --group-name "$APP-sg" --vpc-id "$VPC" \
    --description "Wanderply web" --region "$REGION" --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port 22  --cidr "$MYIP"    --region "$REGION" >/dev/null
  aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port 80  --cidr 0.0.0.0/0  --region "$REGION" >/dev/null
  aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port 443 --cidr 0.0.0.0/0  --region "$REGION" >/dev/null
fi
DB_SG=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=$APP-db-sg" "Name=vpc-id,Values=$VPC" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ "$DB_SG" = None ] || [ -z "$DB_SG" ]; then
  DB_SG=$(aws ec2 create-security-group --group-name "$APP-db-sg" --vpc-id "$VPC" \
    --description "Wanderply RDS" --region "$REGION" --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id "$DB_SG" --protocol tcp --port 5432 \
    --source-group "$APP_SG" --region "$REGION" >/dev/null
fi
echo "✓ security groups app=$APP_SG db=$DB_SG"

# ── 6. EC2 instance + Elastic IP ─────────────────────────────────────────────
AMI=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)
IID=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=$APP-web" "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)
if [ "$IID" = None ] || [ -z "$IID" ]; then
  IID=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI" --instance-type t3.small \
    --key-name "$APP-key" --security-group-ids "$APP_SG" --subnet-id "$SUBNET" \
    --iam-instance-profile Name="$ROLE" \
    --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=30,VolumeType=gp3}' \
    --user-data '#!/bin/bash
dnf install -y docker && systemctl enable --now docker && usermod -aG docker ec2-user' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$APP-web}]" \
    --query 'Instances[0].InstanceId' --output text)
  aws ec2 wait instance-running --instance-ids "$IID" --region "$REGION"
fi
EIP=$(aws ec2 describe-addresses --region "$REGION" --filters "Name=tag:Name,Values=$APP-web" \
  --query 'Addresses[0].PublicIp' --output text 2>/dev/null)
if [ "$EIP" = None ] || [ -z "$EIP" ]; then
  ALLOC=$(aws ec2 allocate-address --domain vpc --region "$REGION" \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$APP-web}]" \
    --query AllocationId --output text)
  aws ec2 associate-address --instance-id "$IID" --allocation-id "$ALLOC" --region "$REGION" >/dev/null
  EIP=$(aws ec2 describe-addresses --region "$REGION" --allocation-ids "$ALLOC" --query 'Addresses[0].PublicIp' --output text)
fi
echo "✓ EC2 $IID  EIP $EIP"

# ── 7. RDS Postgres 17 ───────────────────────────────────────────────────────
DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
if ! aws rds describe-db-instances --db-instance-identifier "$APP-db" --region "$REGION" >/dev/null 2>&1; then
  aws rds create-db-instance --region "$REGION" \
    --db-instance-identifier "$APP-db" --db-instance-class db.t3.micro \
    --engine postgres --engine-version 17.9 --allocated-storage 20 --storage-type gp3 \
    --master-username "${APP}_admin" --master-user-password "$DB_PASS" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" --vpc-security-group-ids "$DB_SG" \
    --no-publicly-accessible --backup-retention-period 7 --no-multi-az >/dev/null
  echo "  waiting for RDS to come up (several minutes)…"
  aws rds wait db-instance-available --db-instance-identifier "$APP-db" --region "$REGION"
  echo "  RDS master password (save it): $DB_PASS"
fi
RDS=$(aws rds describe-db-instances --db-instance-identifier "$APP-db" --region "$REGION" \
  --query 'DBInstances[0].Endpoint.Address' --output text)
echo "✓ RDS $APP-db  endpoint $RDS"

cat <<EOF

────────────────────────────────────────────────────────────
Provisioned. Fill these into config/deploy.yml (or run the sed below):
  Elastic IP : $EIP
  RDS endpoint: $RDS

  sed -i "s/REPLACE_WITH_WANDERPLY_WEB_EIP/$EIP/g;  s/REPLACE_WITH_WANDERPLY_DB_ENDPOINT/$RDS/g" config/deploy.yml

Next (see docs/ops/AWS_DEPLOY.md):
  1. Create the app DB role from the EC2 box (in-VPC), as RDS master:
       ssh -i $KEY_PATH ec2-user@$EIP \\
         'docker run --rm postgres:17 psql "postgresql://${APP}_admin:<MASTER_PW>@$RDS:5432/postgres" \\
            -c "CREATE ROLE plan_my_trip LOGIN PASSWORD '"'"'<APP_DB_PW>'"'"' CREATEDB;" \\
            -c "CREATE DATABASE plan_my_trip_production OWNER plan_my_trip;"'
  2. export PLAN_MY_TRIP_DATABASE_PASSWORD='<APP_DB_PW>'
  3. Route 53: A record wanderply.com + www.wanderply.com → $EIP
  4. kamal setup   (first deploy; installs docker/kamal-proxy, gets Let's Encrypt cert)
  5. kamal app exec 'bin/rails db:seed'
────────────────────────────────────────────────────────────
EOF
