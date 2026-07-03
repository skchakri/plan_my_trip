# Wanderply — DNS + email (SES) setup

Status as of the rebrand: the **Rails app is wired for Amazon SES** and the
**SES domain identity is created** (DKIM + custom MAIL FROM generated, both
`PENDING` until DNS is published). What remains is DNS, which lives in **Route 53**.

- **AWS account:** `727185666062` · **Region:** `us-east-1`
- **SES:** production access already enabled (50k/day) — no sandbox request needed.
- **Sending identity:** `wanderply.com` (Easy DKIM, RSA-2048) + MAIL FROM `mail.wanderply.com`
- **App from-address:** `Wanderply <noreply@wanderply.com>`

## 1. Move DNS to Route 53  *(you — needs Route 53 access)*

1. Route 53 → **Create hosted zone** for `wanderply.com` (public).
2. Copy the **4 NS records** Route 53 assigns.
3. Namecheap → Domain List → `wanderply.com` → **Nameservers → Custom DNS** →
   paste the 4 Route 53 NS values. Propagation: up to a few hours.

## 2. Publish the email records  *(one command, or by hand)*

All values below are already filled with the **real DKIM tokens** SES generated.
Apply the whole set at once (replace `ZONEID` with the new hosted-zone id):

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONEID \
  --change-batch file://docs/ops/route53-wanderply-email.json \
  --region us-east-1
```

Or add them manually in the console:

| Type  | Name                                                          | Value                                                        |
|-------|---------------------------------------------------------------|--------------------------------------------------------------|
| CNAME | `3cuzu7uyc7lvcvlfzxgmqbvn4nwo43ml._domainkey.wanderply.com`   | `3cuzu7uyc7lvcvlfzxgmqbvn4nwo43ml.dkim.amazonses.com`        |
| CNAME | `mt3j4qgmhsbbi3jxgu5u7cyj5fsgj6sg._domainkey.wanderply.com`   | `mt3j4qgmhsbbi3jxgu5u7cyj5fsgj6sg.dkim.amazonses.com`        |
| CNAME | `adsjh3kstc3ezx45lkdjjybtkwpc5ycz._domainkey.wanderply.com`   | `adsjh3kstc3ezx45lkdjjybtkwpc5ycz.dkim.amazonses.com`        |
| MX    | `mail.wanderply.com`                                          | `10 feedback-smtp.us-east-1.amazonses.com`                   |
| TXT   | `mail.wanderply.com`                                          | `"v=spf1 include:amazonses.com ~all"`                        |
| TXT   | `wanderply.com`                                               | `"v=spf1 include:amazonses.com ~all"`                        |
| TXT   | `_dmarc.wanderply.com`                                        | `"v=DMARC1; p=none; rua=mailto:dmarc@wanderply.com; fo=1"`   |

- **DKIM** (3 CNAMEs) → SES signs every message; flips identity to *verified*.
- **MAIL FROM MX + SPF TXT** → aligns the envelope sender to `mail.wanderply.com`.
- **Root SPF** → covers the `From:` domain.
- **DMARC** starts at `p=none` (monitor only). After a week of clean reports, tighten
  to `p=quarantine` then `p=reject`.

## 3. Verify

```bash
aws sesv2 get-email-identity --email-identity wanderply.com --region us-east-1 \
  --query '{DKIM:DkimAttributes.Status, MailFrom:MailFromAttributes.MailFromDomainStatus}'
# want: DKIM "SUCCESS", MailFrom "SUCCESS"
dig +short TXT wanderply.com          # SPF present
dig +short TXT _dmarc.wanderply.com   # DMARC present
```

Send a test once verified:

```bash
aws sesv2 send-email --region us-east-1 \
  --from-email-address "noreply@wanderply.com" \
  --destination ToAddresses=you@example.com \
  --content 'Simple={Subject={Data="Wanderply SES test"},Body={Text={Data="It works."}}}'
```

## 4. Inbound mail — deferred  *(for the forwarded-confirmation parser)*

Action Mailbox is wired (`config.action_mailbox.ingress = :ses`, commented in
`config/environments/production.rb`) but the pipeline isn't built. When needed:

1. SNS topic `wanderply-inbound-mail` + S3 bucket for raw mail.
2. SES **receipt rule** on `inbound.wanderply.com` → S3 + SNS.
3. Add MX: `inbound.wanderply.com → 10 inbound-smtp.us-east-1.amazonaws.com`.
4. Subscribe the topic to `https://wanderply.com/rails/action_mailbox/ses/inbound_emails`
   and fill the real ARN in `production.rb`, then uncomment the ingress block.
   (Requires the app to be deployed at a public URL first.)

## App wiring (already committed)

- `Gemfile` — `aws-actionmailer-ses`, `aws-actionmailbox-ses`, `aws-sdk-sns`.
- `config/environments/production.rb` — `delivery_method = :ses_v2`,
  `ses_v2_settings = { region: "us-east-1" }`, `default_url_options host: wanderply.com`,
  inbound ingress stub. Auth uses the EC2 instance role at deploy time — no keys in the repo.
