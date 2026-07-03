# Wanderply — AWS deploy runbook

Deploys Wanderply to AWS via **Kamal**, mirroring `prof_vault` / `ownsites` in
account `727185666062` (us-east-1): one dedicated **t3.small EC2** (`wanderply-web`)
+ one **db.t3.micro RDS** (`wanderply-db`) + ECR + S3 + IAM instance role, TLS via
kamal-proxy + Let's Encrypt.

**Cost:** ~$30/mo (EC2 ~$15 + RDS ~$13 + EIP/S3/ECR pennies).
**Credentials:** provisioning needs **admin** AWS creds. The `prof-vault-deployer`
user can push to ECR (deploy) but cannot create EC2/RDS/IAM.

## Repo config (already committed)

| File | What it sets |
|---|---|
| `config/deploy.yml` | service/image `wanderply`, ECR registry, web+job on the EC2, kamal-proxy SSL for `wanderply.com`, placeholders for the EIP + RDS endpoint |
| `config/database.yml` | production `host: ENV["DB_HOST"]`, port 5432, `sslmode: require` |
| `config/storage.yml` | `amazon` S3 service → `wanderply-storage` |
| `config/environments/production.rb` | `active_storage.service = :amazon` (SSL/host already set; SES already wired) |
| `.kamal/secrets` | ECR password via `aws ecr get-login-password`; `RAILS_MASTER_KEY` from `config/master.key`; DB password from `$PLAN_MY_TRIP_DATABASE_PASSWORD` (export at deploy, never committed) |
| `Gemfile` | `aws-sdk-s3`, plus the SES gems from the email step |

## 1. Provision (admin creds)

```bash
# with admin AWS creds active:
bash docs/ops/provision-wanderply-aws.sh
```

Creates ECR repo, private S3 bucket, `wanderply-ec2-role` (S3 + SES), key pair
(`~/.ssh/wanderply-key.pem`), security groups, the EC2 + Elastic IP, and the RDS
instance. It prints the **Elastic IP** and **RDS endpoint** and a one-line `sed`
to patch `config/deploy.yml`. **Save the RDS master password it prints.**

## 2. Create the app DB role

The RDS isn't publicly reachable, so run this from the in-VPC EC2 box (the script
prints the exact command). As the RDS **master** user, create the app role +
primary database; Kamal's `db:prepare` then creates the cache/queue/cable DBs:

```sql
CREATE ROLE plan_my_trip LOGIN PASSWORD '<APP_DB_PW>' CREATEDB;
CREATE DATABASE plan_my_trip_production OWNER plan_my_trip;
```

## 3. DNS (Route 53)

Add an **A record** `wanderply.com` and `www.wanderply.com` → the Elastic IP.
(Do this in the same hosted zone as the email records from `DNS_EMAIL_SETUP.md`.)
kamal-proxy needs the name resolving to the box before it can get a cert.

## 4. Deploy

```bash
export PLAN_MY_TRIP_DATABASE_PASSWORD='<APP_DB_PW>'   # the role password from step 2
kamal setup            # first run: bootstraps docker + kamal-proxy, builds, pushes, boots, gets TLS cert
kamal app exec 'bin/rails db:seed'   # geography, quizzes, ai_prompts, demo data
```

Subsequent deploys: `kamal deploy`. Useful: `kamal app logs -f`, `kamal console`,
`kamal app exec 'bin/rails db:migrate'` (migrations also run automatically on deploy).

## 5. Verify

- `https://wanderply.com/up` returns 200 (health check).
- Sign in with the seeded demo account, create a trip, upload a photo (→ S3), and
  confirm a transactional email sends (→ SES; requires the DNS records verified).

## Not yet wired

- **Inbound email** (forwarded-confirmation parser) — SNS/S3/receipt-rule pipeline,
  see `DNS_EMAIL_SETUP.md` §4.
- **CI/CD** — deploys are manual `kamal deploy` from a workstation for now.
