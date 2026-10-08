# ANALYSIS.md — SideDoor Environment Analysis

**Case ID:** CASE-SIDEDOOR
**Environment:** AWS Account <ACCOUNT_ID>, `us-east-1`, cluster `sidedoor-cluster`
**Scope:** Full attack chain execution (see `WALKTHROUGH.md`), followed by a cold-start blue-team triage of the same environment

This document is the investigator's companion to `WALKTHROUGH.md` (the attack) that covers *how the attack chain played out*. `ANALYSIS.md` covers *how an analyst would actually gather findings*, i.e., the exact commands run, the evidence each one produced, and the dead ends along the way. It's meant to be written as a real case file.

**On trigger:** there was no alert that kicked this off which means, no GuardDuty finding, no CloudWatch alarm system that could trigger an alert. This was a self-initiated cold triage, working the account the way an analyst would if handed it with zero context: start from CloudTrail, follow the evidence, and see what turns up.

---

## Methodology

Every piece of CloudTrail evidence here follows one rule: **pull it once into a saved file, then analyze that file offline.**. This isn't an AWS-specific habit; it's the same discipline used for any forensics work as well like Windows Event Logs or EDR data.

Two practical lessons shaped how evidence was collected:

- **Filter by identity, not by event type.** Filtering by `Username` instead (CloudTrail stores the EC2 instance ID here for instance-role sessions) pulls *everything* one specific identity did, across every AWS service, in a single query and leaves the unrelated operator activity out entirely.
- **CloudTrail has sharp edges worth knowing about.** `lookup-events` returns results newest-first, and Delivery can lag up to ~15 minutes behind real time. And a re-exported file is not automatically a *new* file.

---

## IOC Summary

| IOC | Type | Notes |
|---|---|---|
| `staffsync-app-server-role` | IAM role (EC2 instance role) | Stolen via SSRF→IMDS; the compromised identity behind every finding below |
| `<INSTANCE_ID>` | EC2 instance ID | A new one per environment rebuild; each becomes a new `Username` value for the same role |
| `<ANALYST_SOURCE_IP>` | Source IP | Outside the VPC — every stolen-credential call came from an analyst workstation, not from inside the compromised environment |
| `AJUN...` (rotating) | Temporary AccessKeyId | Changes every time the SSRF step is re-run; tied to `staffsync-app-server-role` sessions |
| `sidedoor-app-execution-role` | IAM role (task execution role) | Legitimate — handles app container logging. Shows up in CloudTrail as background noise, not part of the attack |
| `flag-task-role` | IAM role (task role) | Holds session-access (`ssmmessages:*`) permissions — not itself part of the privilege-escalation path |

---

## Case Journal

### Phase: Detection & Analysis

**Entry 01: Finding the right way to isolate the attacker**

*What happened:* The first CloudTrail pull filtered only by event source (`iam.amazonaws.com`) and came back with a mix of calls that didn't all belong to the compromised identity — including a `GetRolePolicy` call that couldn't have been the attacker's, since the compromised role's own policy explicitly denies that action.

*Commands run:*
```bash
# Too broad — picks up unrelated account activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=iam.amazonaws.com \
  --start-time "2026-10-06T00:00:00Z" \
  --end-time "2026-10-06T13:00:00Z" \
  --region us-east-1

# Fixed — scoped to the compromised identity specifically
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<INSTANCE_ROLE_ID> \
  --start-time "2026-10-06T00:00:00Z" \
  --end-time "2026-10-06T13:00:00Z" \
  --region us-east-1
```

*Why it matters:* Event-source filtering returns every caller touching that service, attacker and legitimate activity alike — there's no way to tell at a glance which calls belong to the identity under investigation. Filtering by identity instead pulls everything one specific caller did, across every service in a single query.

**Entry 02: Confirming the stolen credentials, and how they were obtained**

*What happened:* Using the stolen session, the attacker confirmed their identity. CloudTrail recorded the call with `ec2RoleDelivery` set to `"1.0"`.

*Commands run:*
```bash
# Attacker side — confirming the stolen session is live
aws sts get-caller-identity --profile trial --region us-east-1

# Analyst side — finding the matching CloudTrail record
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetCallerIdentity \
  --start-time "2026-10-03T00:00:00Z" \
  --end-time "2026-10-03T23:59:59Z" \
  --region us-east-1
```

*Why it matters:* `ec2RoleDelivery` records which version of the instance metadata service handed out the credentials. `"1.0"` means the old and unauthenticated version (IMDSv1) where no token required. This is exactly the version this environment's SSRF exploit depends on. That one field is direct proof the credentials were obtained through the unauthenticated path.

*ATT&CK:* T1552.005 — Unsecured Credentials: Cloud Instance Metadata API

**Entry 03: The credentials were used from outside the environment entirely**
 
*What happened:* Every call made with the stolen role came from `<ANALYST_SOURCE_IP>`, not from anywhere inside the VPC.
 
*Why it matters:* Under normal operation, this role should only ever be used from inside the ECS task network. A stolen instance role being used from an external IP is a specific, well-known red flag. AWS GuardDuty has a finding type built around exactly this pattern. GuardDuty wasn't enabled on this account, so this wasn't independently confirmed against a live finding.
 
*ATT&CK:* T1078.004 — Valid Accounts: Cloud Accounts
 
---
 
### Phase: Scoping
 
**Entry 04: Proving the IAM scoping works, by watching it fail**
 
*What happened:* The compromised role ran its own reconnaissance against its identity, and one of those calls was explicitly denied.
 
*Commands run (attacker side):*
```bash
aws iam get-role --role-name staffsync-app-server-role --profile trial --region us-east-1
aws iam list-role-policies --role-name staffsync-app-server-role --profile trial --region us-east-1
aws iam list-attached-role-policies --role-name staffsync-app-server-role --profile trial --region us-east-1
aws iam get-role-policy --role-name staffsync-app-server-role --policy-name self-enumeration --profile trial --region us-east-1
# ^ this one returns AccessDeniedException
```
 
*Commands run (analyst side, confirming it in CloudTrail):*
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<INSTANCE_ROLE_ID> \
  --start-time "2026-10-06T00:00:00Z" \
  --end-time "2026-10-06T23:59:59Z" \
  --region us-east-1 \
  --output json | jq '.Events[] | select(.EventName=="GetRolePolicy")'
```
 
*Why it matters:* The first three calls succeed and tell the attacker a policy exists, by name. The fourth is refused. That's stronger evidence than simply never seeing a `GetRolePolicy` call at all, and it shows the boundary being actively tested and actively held, not just assumed.
 
*ATT&CK:* T1087.004 — Account Discovery: Cloud Account
 
**Entry 05: Mapping out the ECS environment**
 
*What happened:* With the IAM boundary confirmed in Entry 04, checking what the same identity did in ECS before any pivot attempt.
 
*Commands run (analyst side):*
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<INSTANCE_ROLE_ID> \
  --start-time "2026-10-06T00:00:00Z" \
  --end-time "2026-10-06T23:59:59Z" \
  --region us-east-1 \
  --output json | jq '.Events[] | select(.EventSource=="ecs.amazonaws.com")'
```
 
*Why it matters:* This surfaces `ListClusters`, `ListTasks`, and `DescribeTasks` under the compromised identity — full discovery of both running containers, `payroll-app` and `flag-holder`, before any pivot attempt. None of the IAM conditions restrict these discovery-level calls; only the later `ExecuteCommand` step carries one.
 
*ATT&CK:* T1526 — Cloud Service Discovery
 
---
 
### Phase: Lateral Movement
 
**Entry 06: Looking for the `payroll-app` attempt in CloudTrail**
 
*What happened:* An attempt to get a shell on the "payroll-app" container
 
*Commands run (analyst side):*
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ExecuteCommand \
  --start-time "2026-10-06T00:00:00Z" \
  --end-time "2026-10-06T23:59:59Z" \
  --region us-east-1 \
  --output json | jq '.Events[] | select(.CloudTrailEvent | contains("payroll-app"))'
```
*Result:* Didnt' succeed. Returned an `InvalidParameter Exception`

**Entry 07: Confirming the successful pivot via CloudTrail**
 
*What happened:* Checking the same `ExecuteCommand` pull for the session against `flag-holder`.
 
*Commands run (analyst side):*
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ExecuteCommand \
  --start-time "2026-10-06T00:00:00Z" \
  --end-time "2026-10-06T23:59:59Z" \
  --region us-east-1 \
  --output json | jq '.Events[] | select(.CloudTrailEvent | contains("flag-holder"))'
```
 
*Why it matters:* This confirms the session independently of `WALKTHROUGH.md`'s own output, i.e., a successful `ExecuteCommand` call against `flag-holder`, with a `SessionId` (`ecs-execute-command-l5egyr8uq9jqjr5u2g2b6yldu8`) and no `errorCode`. This is the real proof of the IAM condition's allow branch — `ecs:container-name = flag-holder` — actually working, completing the cross-role pivot.
 
*ATT&CK:* T1609 — Container Administration Command
 
---
 
## ATT&CK Technique Mapping
 
| ID | Technique | Tactic | Chain Step | Detection Status |
|---|---|---|---|---|
| T1190 | Exploit Public-Facing Application | Initial Access | Mass assignment + IDOR (see `WALKTHROUGH.md`) | No trace in CloudTrail: web-layer, never reaches AWS management-plane logging |
| T1552.005 | Unsecured Credentials: Cloud Instance Metadata API | Credential Access | SSRF against IMDS (Entry 02) | No trace in CloudTrail: Link-Local call |
| T1078.004 | Valid Accounts: Cloud Accounts | Defense Evasion | Stolen role used from outside the VPC (Entries 02–03) | Logged, not alerted |
| T1087.004 | Account Discovery: Cloud Account | Discovery | IAM self-enumeration (Entry 04) | Logged, not alerted |
| T1526 | Cloud Service Discovery | Discovery | ECS discovery chain (Entry 05) | Logged, not alerted |
| T1609 | Container Administration Command | Execution | `ExecuteCommand` pivot (Entries 06–07) | Logged, not alerted |
 
---
 
## Containment (not executed — documented for completeness)
 
This is a built environment, not a live incident, so no containment action was actually taken. For the record, here's the right order of operations given this setup:
 
1. **Attach an explicit Deny policy** to `staffsync-app-server-role` — this takes effect on the very next API call, because IAM evaluates permissions live, regardless of what credentials are already cached somewhere.
2. **Quarantine the EC2 instance** by moving it to an isolated security group, rather than terminating it outright. This preserves whatever evidence does exist on the host for further analysis, rather than destroying it.
3. **Only after evidence is captured**, replace the instance and redeploy clean.
 
---
 
## Lessons Learned
 
- **Nothing in this investigation would have surfaced on its own.** There was no alert anywhere in the chain. A real environment needs GuardDuty (or equivalent) actually running to catch the IMDSv1 credential theft and the external-IP credential use documented in Entries 02–03.
- **Filter by identity, not by service, in any account with real background activity.** Service-level filtering mixes attacker and operator noise together.