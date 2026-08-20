# Cloud week runbook

This is the whole week in order: an empty AWS account on the first afternoon, a verified
deployment and a shared link on the last. There is no instructor to fill a gap in it, so it is
written to be followed literally, including by somebody reading it on paper.

Every step has the same three parts.

- **Do.** The exact commands, in order.
- **Success looks like.** The output or console state that means the step worked.
- **If that is not what happened.** The failures this step actually produces, and the next
  action for each.

No step ends without a next action. If you reach one that does, that is a defect in this
document: write it down, take the nearest matching action, and hand the note in with the
deployment.

Work through the steps in sequence. Several of them exist only so that a later failure is
readable when it arrives, and skipping them does not save the time it looks like it saves.

## The placeholder convention

Anything in capitals inside angle brackets is a value you supply. Replace the brackets as well
as the text. `<BUCKET>` means type your bucket name in that position, so
`s3://<BUCKET>/` becomes `s3://etp-team4-ui/`.

Placeholders in lowercase, `<team>` and `<port>`, are free text: your team's name, a port your
local stack already publishes. Only the capitalised ones are tracked.

Placeholders are never quoted differently from the rest of a command. If a command shows
`--paths '/index.html'`, the quotes are part of the command and stay.

Every placeholder in this runbook is in the record sheet below, with one exception. `<KEY_ID>`
is the access key id of the deploy user, which is half a credential: read it back from IAM with
`aws iam list-access-keys` at the two steps that need it, and write it nowhere.

Fill the sheet in as you go, one copy per team, somewhere every member can read it. It is not a
secret document: it holds identifiers, and the only credential it mentions is the one it tells
you not to write down.

## The record sheet

| Placeholder | What it is | Filled in at |
|---|---|---|
| `<REGION>` | The AWS region for the bucket. `ap-south-1` for this cohort. | Step 5 |
| `<ACCOUNT_ID>` | Your twelve-digit AWS account id. | Step 4 |
| `<SETUP_PROFILE>` | The AWS CLI profile for the setup identity. `etp-setup` is fine. | Step 4 |
| `<BUCKET>` | The bucket holding the build. Lowercase, no dots. | Step 6 |
| `<DEPLOY_USER>` | The IAM user the automation runs as. `etp-deploy` is fine. | Step 10 |
| `<DEPLOY_PROFILE>` | The AWS CLI profile for the deploy identity. `etp-deploy` is fine. | Step 13 |
| `<DIST_DIR>` | The directory the Angular build writes into. | Step 18 |
| `<OAC_ID>` | The id of the origin access control. Starts with `E`. | Step 23 |
| `<DIST_ID>` | The id of the distribution. Starts with `E`. | Step 25 |
| `<DIST_DOMAIN>` | The distribution's own domain, ending `.cloudfront.net`. | Step 25 |
| `<ETAG>` | The version marker CloudFront gives you when you read a configuration. Changes on every write. | Steps 28, T1 |
| `<INVALIDATION_ID>` | The id of an invalidation. Starts with `I`. | Step 30 |

Two values are never written on this sheet, never pasted into a document, and never committed:
the access key id and the secret access key of `<DEPLOY_USER>`. Step 13 says where they go.

## The week at a glance

| Day | Steps | You finish with | Slack |
|---|---|---|---|
| 0.5 | 1 to 6 | Account access, AWS CLI v2, a region, an agreed bucket name | None. Account access not working by the end of the half day is the one thing to escalate the same afternoon. |
| 1 | 7 to 14 | A private bucket, a scoped deploy identity, and proof it is scoped | Half a day. IAM takes it. |
| 2 | 15 to 22 | A production build in the bucket, with the API base URL decided | Little. This is the day that overruns, because the API base URL and the cross-origin work are yours to reason about. |
| 3 | 23 to 30 | The distribution serving your application over HTTPS, deep links working, an invalidation completed | Two waits of five to ten minutes. The steps say what to do inside them. |
| 4 | 31 to 37 | One command that deploys, verified end to end, link shared | An afternoon, if day 2 did not eat it. |

Half a day plus four days is the four and a half the week is scheduled for. Teardown is not in
it: it happens after your assessment is confirmed, and takes about twenty minutes.

Commands are run from the repository root unless a step says otherwise.

---

# Day 0.5: access, tooling and a region

## Step 1. Confirm the prerequisite before anything else

**Do** start your local stack the way your team's orchestration starts it, then list the
containers it brought up and confirm each one is running.

Then sign in the way the Angular application does and put one request to a route from each of
your four Sprint 10 modules, and place one order through the Trade REST API and watch it fill.

**Success looks like** every container in your stack with state `running`, four module
routes answering a real token, and one order reaching a terminal status.

**If that is not what happened**

- **A container is not running, or a route does not answer.** Stop the cloud week here and fix
  it. Everything from Step 15 onwards verifies against this stack, and debugging it through a CDN
  is several times harder than debugging it now.
- **Only the Kafka-dependent paths fail.** Give the stack a minute after starting it and try
  again. Consumers take time to join.

Nothing after this step stops, starts or reconfigures a container. If you did not start it, do
not touch it.

## Step 2. Attend the guardrails briefing

**Do** attend the Fidelity platform SME session on how Fidelity governs its AWS estate, with the
whole team, before Step 4. It happens before any hands-on work, it is a briefing and not a lab,
and you deploy nothing to anything belonging to Fidelity.

**Success looks like** every member of the team able to say which account they are permitted to
work in, who owns it, and what happens to it at the end of the programme.

**If that is not what happened** ask the alumni before Step 4. Working in the wrong account is
the one mistake in this week that is not yours to undo.

## Step 3. Install or confirm AWS CLI v2

**Do**

```bash
aws --version
```

**Success looks like** a version string beginning `aws-cli/2.`, for example
`aws-cli/2.17.0 Python/3.11.9 Linux/6.5.0 exe/x86_64`.

**If that is not what happened**

- **`command not found`.** Install AWS CLI v2 for your operating system from the AWS
  documentation. Do not install it with `pip`, which gets you v1.
- **The version begins `aws-cli/1.`.** Every command in this runbook is v2. Uninstall v1 or put
  v2 ahead of it on your `PATH`, then run `aws --version` again before continuing.
- **Different versions across the team.** Acceptable within v2. Note the versions on the record
  sheet if output shapes differ from what this runbook describes.

## Step 4. Configure the setup identity and prove who you are

The setup identity is the one that creates things. It is used by a human, by hand.

**Do**, if you were given a sign-in URL for IAM Identity Center:

```bash
aws configure sso --profile <SETUP_PROFILE>
aws sso login --profile <SETUP_PROFILE>
```

**Do**, if you were given an access key pair instead:

```bash
aws configure --profile <SETUP_PROFILE>
```

Answer the four prompts. Region is `<REGION>`, output format is `json`. Type the secret at the
prompt rather than passing it on a command line, so it does not reach your shell history.

Then, either way:

```bash
aws sts get-caller-identity --profile <SETUP_PROFILE>
```

**Success looks like** three fields, and the account matching the one from Step 2:

```json
{
    "UserId": "AIDA...",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/<your-user>"
}
```

Write the account id on the record sheet.

**If that is not what happened**

- **`Unable to locate credentials`.** The profile does not exist or is misspelled. List what you
  have with `aws configure list-profiles`.
- **`The security token included in the request is invalid`.** For an Identity Center profile the
  session has expired: run `aws sso login --profile <SETUP_PROFILE>` again. For a key pair, the
  key has been deactivated or mistyped.
- **The account id is not the one from Step 2.** Stop and ask the alumni. Do not create anything
  in an account you were not given.
- **`AccessDenied` on `sts get-caller-identity`.** That call is permitted to every identity, so a
  denial means something above you is blocking the region or the account. Escalate it.

## Step 5. Fix the region, once, for the week

**Do**

```bash
aws configure set region ap-south-1 --profile <SETUP_PROFILE>
aws configure get region --profile <SETUP_PROFILE>
```

**Success looks like** `ap-south-1` printed back. That is `<REGION>` for the rest of the week.

**If that is not what happened**

- **Nothing is printed.** The profile has no region. Run the `set` command again and check the
  profile name matches.
- **The team has two regions between them.** Fix it now. A region mismatch does not announce
  itself: it turns up as `PermanentRedirect` on an upload or as a distribution that cannot read
  its origin, and both read like something else.

CloudFront is global, so the region decides only where the bucket lives. It still has to be the
same one everywhere.

## Step 6. Agree the bucket name

**Do** agree one bucket name and write it on the record sheet as `<BUCKET>`.

S3 bucket names are globally unique across every AWS account in the world, so `etp-ui` has been
taken for years. Use `etp-<team>-ui`, all lowercase.

Three rules, and the third one costs an afternoon when it is broken:

- Three to sixty-three characters, lowercase letters, digits and hyphens.
- No uppercase and no underscores.
- **No dots.** A dot in the name breaks the TLS certificate on the bucket's own HTTPS endpoint,
  which turns the Step 22 verification into an unreadable certificate error rather than the
  denial you are looking for.

**Success looks like** one name written on the record sheet as `<BUCKET>`, agreed by the whole
team, matching those rules.

**If that is not what happened**, that is the whole of Step 6. Nothing has been created yet.

---

# Day 1: the bucket and the two identities

## Step 7. Create the bucket

**Do**

```bash
aws s3api create-bucket \
  --bucket <BUCKET> \
  --region <REGION> \
  --create-bucket-configuration LocationConstraint=<REGION> \
  --profile <SETUP_PROFILE>
```

**Success looks like**

```json
{
    "Location": "http://<BUCKET>.s3.amazonaws.com/"
}
```

**If that is not what happened**

- **`IllegalLocationConstraintException`.** The `--create-bucket-configuration` is missing or
  names a different region from `--region`. Every region except `us-east-1` requires it, and the
  two values must match.
- **`BucketAlreadyExists`.** Somebody in the world owns that name. Pick another, update the
  record sheet, and tell the team before anyone else uses the old one.
- **`BucketAlreadyOwnedByYou`.** You already ran this step. Nothing is wrong. Go to Step 8.
- **`InvalidBucketName`.** Uppercase, an underscore, or a leading or trailing hyphen. Re-read
  Step 6.
- **`AccessDenied`.** The training account restricts bucket creation. Take the exact message to
  the alumni rather than trying other regions.

## Step 8. Make it private, explicitly

New buckets are private by default. Set it anyway, because criterion 2 is a bucket that refuses,
and a default you did not set is a default somebody can change without noticing.

**Do**

```bash
aws s3api put-public-access-block \
  --bucket <BUCKET> \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile <SETUP_PROFILE>

aws s3api get-public-access-block --bucket <BUCKET> --profile <SETUP_PROFILE>
```

**Success looks like** no output at all from the first command, and four `true` values from the
second:

```json
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}
```

**If that is not what happened**

- **Any value is `false`.** Run the first command again and read it character by character. The
  configuration is a single comma-separated argument with no spaces around the commas.
- **`NoSuchPublicAccessBlockConfiguration` from the second command.** The first one did not
  apply. Check the bucket name.
- **A shell error about an unexpected token.** Your shell split the configuration on the line
  break. Put the whole `BlockPublicAcls=...RestrictPublicBuckets=true` on one line.

## Step 9. Confirm it refuses, from outside

**Do**

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<BUCKET>.s3.<REGION>.amazonaws.com/index.html
```

**Success looks like** `403`. There is nothing in the bucket yet, and a private bucket refuses an
anonymous caller before it tells them whether an object exists. That refusal is the state you
want, on an empty bucket and on a full one.

**If that is not what happened**

- **`404`.** Read the body with `curl -s https://<BUCKET>.s3.<REGION>.amazonaws.com/index.html`.
  A `<Code>NoSuchBucket</Code>` means the name or the region is wrong, not that the bucket is
  private. Any other 404 means the caller is allowed to list the bucket, which is more access
  than criterion 2 allows.
- **`301` or `307`, with `PermanentRedirect` in the body.** The bucket is in a different region
  from the one in the URL. You have two regions in play. Go back to Step 5.
- **`curl: (60)` and a certificate message.** Your bucket name contains a dot. The certificate on
  `*.s3.<REGION>.amazonaws.com` does not cover a name with another dot in it. Delete the bucket
  with `aws s3api delete-bucket --bucket <BUCKET> --region <REGION> --profile <SETUP_PROFILE>`
  and go back to Step 6.
- **`200`.** The bucket is public. Go back to Step 8 and check nothing else has attached a
  policy.

## Step 10. Create the deploy user

**Do**

```bash
aws iam create-user --user-name <DEPLOY_USER> --profile <SETUP_PROFILE>
```

**Success looks like**

```json
{
    "User": {
        "Path": "/",
        "UserName": "<DEPLOY_USER>",
        "UserId": "AIDA...",
        "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/<DEPLOY_USER>",
        "CreateDate": "..."
    }
}
```

**If that is not what happened**

- **`EntityAlreadyExists`.** Somebody on the team already made it. Nothing is wrong. Go to
  Step 11 and agree who is driving.
- **`AccessDenied`.** The setup identity cannot create users in this account. Take the message to
  the alumni: the alternative is a role they provision for you, and the rest of this runbook is
  unchanged apart from how Step 13 gets its credentials.

## Step 11. Write the deploy policy

**Do** copy `sprint-11-cloud-deploy/iam/policy-skeleton.json` to `deploy/iam/deploy-policy.json`
and fill it in. That file is committed: it holds identifiers and no credentials.

Replace the three resource ARNs with your bucket name, your account id and, on Day 3, your
distribution id. Until the distribution exists, leave the third statement out entirely rather
than pointing it at a guess. Step 29 puts it back.

The actions are yours to work out, and working them out is part of criterion 6. Two things make
that tractable without anybody to ask.

Derive them from the commands you are about to run. Step 20 runs `aws s3 sync` with `--delete`
against the bucket, and Step 21 runs `aws s3 cp`. Ask what each one has to do to the bucket:
find out what is already there, write an object, remove an object that is no longer in the
build. Each of those is one S3 action, and the bucket-level one belongs in `ListTargetBucket`
while the object-level ones belong in `WriteObjectsInTargetBucket`.

Then let AWS correct you. When the deploy identity is missing an action, the CLI says so by
name:

```
An error occurred (AccessDenied) when calling the PutObject operation: User:
arn:aws:iam::<ACCOUNT_ID>:user/<DEPLOY_USER> is not authorized to perform: s3:PutObject
on resource: "arn:aws:s3:::<BUCKET>/index.html"
```

Add the action it names, and only that one, then run the command again. Three iterations is a
normal result and is exactly how you would scope a policy in a real estate.

**Success looks like** a JSON file with no `REPLACE_` strings left in it, two statements for now,
and no `*` in any action or resource.

**If that is not what happened**

- **You are tempted to write `"Action": "s3:*"` or `"Resource": "*"`.** That fails criterion 6
  whether or not the deploy works, and it is read directly from this committed file. Iterate
  instead.
- **You cannot tell which statement an action belongs in.** Bucket-level actions name the bucket
  ARN without `/*` and answer questions about the bucket. Object-level actions name the ARN with
  `/*` and act on one key.

## Step 12. Attach it

**Do**

```bash
aws iam put-user-policy \
  --user-name <DEPLOY_USER> \
  --policy-name etp-deploy \
  --policy-document file://deploy/iam/deploy-policy.json \
  --profile <SETUP_PROFILE>

aws iam get-user-policy \
  --user-name <DEPLOY_USER> \
  --policy-name etp-deploy \
  --profile <SETUP_PROFILE>
```

**Success looks like** no output from the first command, and the policy you wrote read back by
the second.

This command replaces the inline policy of that name in place, so running it again after editing
the file is the normal way to change the policy. You will do exactly that at Step 29.

**If that is not what happened**

- **`MalformedPolicyDocument`.** The message names the offending element. An invalid action name
  and a missing comma both land here. Validate the JSON, then check every action against the
  service prefix, which is `s3:` or `cloudfront:`.
- **`NoSuchEntity`.** The user name does not match Step 10.
- **`Error parsing parameter '--policy-document'`.** The `file://` path is relative to the
  directory you are standing in. Run it from the repository root, as written.

## Step 13. Create the access key and put it somewhere safe

**Do**

```bash
aws iam create-access-key --user-name <DEPLOY_USER> --profile <SETUP_PROFILE>
```

**Success looks like** one JSON object containing `AccessKeyId` and `SecretAccessKey`. The secret
is shown once, here, and never again.

Now put the pair where the thing that needs it can read it, and nowhere else.

For a local deploy:

```bash
aws configure --profile <DEPLOY_PROFILE>
```

Paste the key id and the secret at the prompts, set the region to `<REGION>` and the output to
`json`. They land in `~/.aws/credentials`, which is outside the repository. Do not use
`aws configure set aws_secret_access_key <value>`: that writes the secret into your shell
history, where the next person to run `history` finds it.

The region, the bucket name and the distribution id are not secrets. Pass them to the script
as arguments, or export them in the shell that runs it, so that the real secrets are easy to
find.

**Success also looks like** nothing key-shaped anywhere in the repository. Search the working
tree and this folder's recorded history for an `AKIA` prefix and for a forty-character secret
now, while a mistake is one file old.

**If that is not what happened**

- **`LimitExceeded`.** The user already has two keys. List them with
  `aws iam list-access-keys --user-name <DEPLOY_USER>`, and delete the one nobody is using with
  `aws iam delete-access-key --user-name <DEPLOY_USER> --access-key-id <KEY_ID>`.
- **You closed the terminal before saving the secret.** It cannot be recovered. Delete that key
  and create another. That is the correct response and it costs a minute.
- **You find an access key id in the tree.** Treat it as disclosed. Deactivate and delete the
  key in IAM first, then take it out of the file, then create a new one. That order is not
  negotiable: removing it from the file first leaves a live credential in the history.

## Step 14. Prove the deploy identity is limited

A scoped policy you have not tested is a policy you are guessing about.

**Do**

```bash
aws sts get-caller-identity --profile <DEPLOY_PROFILE>

aws s3api create-bucket \
  --bucket <BUCKET>-should-not-exist \
  --region <REGION> \
  --create-bucket-configuration LocationConstraint=<REGION> \
  --profile <DEPLOY_PROFILE>
```

**Success looks like** the first command naming `arn:aws:iam::<ACCOUNT_ID>:user/<DEPLOY_USER>`,
and the second command failing:

```
An error occurred (AccessDenied) when calling the CreateBucket operation: User:
arn:aws:iam::<ACCOUNT_ID>:user/<DEPLOY_USER> is not authorized to perform: s3:CreateBucket
```

The failure is the pass. Record that you ran it.

**If that is not what happened**

- **The bucket was created.** Your policy is too broad. Delete the bucket immediately with
  `aws s3api delete-bucket --bucket <BUCKET>-should-not-exist --region <REGION> --profile
  <SETUP_PROFILE>`, then go back to Step 11 and find the wildcard.
- **The first command fails.** The deploy profile is not configured. Go back to Step 13.

---

# Day 2: the build, and where it points

## Step 15. Decide what the deployed build calls

**Do** take this decision as a team, before you build anything, and write it in the decision log
the same hour.

Your Trade REST API and Auth service run in your local stack on a laptop. The Angular application
is about to be served from a CDN. The bundle carries whatever API address it was built with, and
that address is resolved by the browser that loaded the page, not by the machine that built it.

The route this runbook takes: **build the cloud configuration to point at `http://localhost` on
the ports your local stack already publishes.** The deployed page then loads for anybody in the
world, and the authenticated flows work on any machine that is running the stack, which is every
machine in your team. Verification in Step 34 happens on one of them.

What that route costs, stated plainly so you can defend it: a visitor with no local stack sees
the application shell and a failed sign-in. That is a training deployment of a front end whose
back end was never in scope, and it is what you say when you share the link.

The alternatives, so you know you chose:

| Option | What it buys | What it costs |
|---|---|---|
| `http://localhost:<port>` | Works from every team machine with no extra infrastructure | Useless to anyone not running the stack |
| A temporary HTTPS tunnel to one laptop | A link that works for anyone, while the laptop is on | A public route into a development stack, one machine everyone depends on, and network policy that may forbid it. Ask the alumni before doing this on a Fidelity network. |
| Deploying the back end | A real deployment | Out of scope for this programme, and not what the criteria ask for |

One rule applies to every option. The address is a build-time configuration value in an Angular
environment file, committed, and it is not edited by hand before a deploy. An address is not a
secret. A key is, and no key goes anywhere near this build.

**Success looks like** a decision-log entry naming the option, the reason and the consequence.

**If that is not what happened**, take the first row. It needs nothing you do not already have.

## Step 16. Point the build at it

**Do** in `sprint-09-trading-ui`, add or edit the environment file your production configuration
already uses, so the API base URLs are the ones from Step 15. Your Sprint 9 workspace decided
where that file lives and what the values are called; this runbook does not, because it did not
write your workspace.

**Success looks like** `grep -rn "localhost" src/environments/` (or wherever yours are) showing
the API base URLs for the production configuration, and no key of any kind alongside them.

**If that is not what happened**

- **There is no production environment file.** Angular's default `production` configuration may
  build without one. Add the file and the `fileReplacements` entry in `angular.json`, or read
  the address from a single exported constant that the production configuration replaces. Either
  is acceptable. A value edited by hand before each deploy is not.
- **You cannot find where the base URL is set.** It is wherever your generated clients are
  configured with a base path. Search for the port number your local stack publishes.

## Step 17. Let the deployed origin call your services

The page's origin is about to become `https://<DIST_DOMAIN>`, which your services have never
seen. A browser will not hand your JavaScript a response from a different origin unless the
service says it may.

**Do** add the distribution origin to the cross-origin configuration of the Trade REST API and
the Auth service. You do not have `<DIST_DOMAIN>` until Step 25, so this step is completed then;
do the reading now and leave the change ready.

Three things to get right:

- Name the exact origin. `https://<DIST_DOMAIN>`, with no trailing slash.
- Allow the methods the application uses and the `Authorization` header. A preflight that
  succeeds and a real request that fails is almost always a missing allowed header.
- Do not allow every origin on a service that holds customer positions. If your client sends
  credentials, a wildcard origin is rejected by the browser anyway.

**Success looks like** both services restarted with the new configuration, verified at Step 34.

**If that is not what happened**, note it and carry on. This step cannot be finished before
Step 25, and Step 34 is where it is proven.

## Step 18. Build

**Do**

```bash
cd sprint-09-trading-ui
npm ci
npm run build
ls dist/*/browser/index.html
cd ..
```

**Success looks like** `npm ci` completing, a build summary with the initial bundle sizes, and
`ls` printing one path. That path's directory is `<DIST_DIR>`, for example
`sprint-09-trading-ui/dist/trading-ui/browser`. Write it on the record sheet.

**If that is not what happened**

- **`npm ci can only install packages when your package.json and package-lock.json are in
  sync`.** Run `npm install`, commit the updated `package-lock.json`, then run `npm ci` again.
  Do not replace `npm ci` with `npm install` in the deploy: the whole point is that the build is
  reproducible.
- **A Node version error.** Angular 21 refuses to start below Node 20.19. Check with
  `node --version`.
- **`ls` prints nothing.** Your builder writes somewhere else. Read the `outputPath` in
  `angular.json` and use that, plus `/browser` if your builder emits one.
- **`ls` prints more than one path.** The workspace has more than one project. Name the one the
  application builds from.

## Step 19. Read the bundle before the world does

Sprint 9 checked this on your machine when the bundle was private. It is about to become a
public object on a CDN, cached at edges you do not control, and a key that reaches it has been
disclosed rather than risked.

**Do**

```bash
grep -rIEil 'x-api-key|api[_-]key|fauxnance|jwt[_-]?secret|execute-api\.[a-z0-9-]+\.amazonaws\.com' <DIST_DIR>
```

**Success looks like** no output at all.

**If that is not what happened**

- **A file is named.** Do not upload. Find the value, take it out of the source, and if it is a
  real Fauxnance key or a real signing secret, have it rotated today. Removing it from the next
  build does not undo a disclosure, and Step 33 reads the deployed copy anyway.
- **A match that is a false positive**, a variable named `apiKey` that holds nothing, for
  instance. Read the surrounding text and satisfy yourself. Then rename it, because the next
  person to run this grep will stop on it too.

## Step 20. Upload the hashed assets

Two families of file go up with different cache headers. Hashed assets first, because
`index.html` is the pointer to them and must never point at something that is not there yet.

**Do**

```bash
aws s3 sync <DIST_DIR>/ s3://<BUCKET>/ \
  --delete \
  --exclude index.html \
  --cache-control 'public,max-age=31536000,immutable' \
  --profile <DEPLOY_PROFILE>
```

**Success looks like** one `upload:` line per file:

```
upload: <DIST_DIR>/main-A1B2C3D4.js to s3://<BUCKET>/main-A1B2C3D4.js
upload: <DIST_DIR>/styles-E5F6A7B8.css to s3://<BUCKET>/styles-E5F6A7B8.css
```

`--delete` removes objects in the bucket that are not in this build, so the bucket ends up
holding this build rather than a mixture. `--exclude index.html` keeps the sync away from the
one file whose headers are different.

**If that is not what happened**

- **`AccessDenied ... not authorized to perform: s3:PutObject`**, or the same for another action.
  The message names the action. Add it to `deploy/iam/deploy-policy.json`, run Step 12 again,
  and run this step again. This is Step 11 working as intended.
- **`AccessDenied ... s3:ListBucket`.** The bucket-level statement is missing or its resource ARN
  has `/*` on the end. A sync lists before it writes.
- **`PermanentRedirect`.** The deploy profile's region is not the bucket's region. Fix it with
  `aws configure set region <REGION> --profile <DEPLOY_PROFILE>`.
- **`NoSuchBucket`.** The bucket name is wrong, or the bucket is in another account.
- **`The user-provided path ... does not exist`.** `<DIST_DIR>` is wrong. Go back to Step 18.

## Step 21. Upload the index, uncached

**Do**

```bash
aws s3 cp <DIST_DIR>/index.html s3://<BUCKET>/index.html \
  --cache-control 'no-cache' \
  --content-type 'text/html' \
  --profile <DEPLOY_PROFILE>
```

**Success looks like** one `upload:` line for `index.html`.

`no-cache` does not mean do not store it. It means revalidate before serving it, which is what
you want from the file that says which hashed assets are current. The assets themselves are
immutable for a year because their names change when their contents do.

**If that is not what happened**

- **`AccessDenied`.** Same action-naming loop as Step 20.
- **The content type comes back as `binary/octet-stream` later.** You omitted `--content-type`.
  Run the command again as written; a re-upload of the same key replaces it.

## Step 22. Confirm what is in the bucket, and that it is still shut

**Do**

```bash
aws s3api list-objects-v2 --bucket <BUCKET> \
  --query 'Contents[].Key' --output text --profile <DEPLOY_PROFILE>

curl -s -o /dev/null -w '%{http_code}\n' https://<BUCKET>.s3.<REGION>.amazonaws.com/index.html
```

**Success looks like** your build's filenames from the first command, including `index.html`,
and `403` from the second. The bucket holds the application and refuses to serve it to the
internet. Nothing can read it yet, and that is the correct state at the end of Day 2.

**If that is not what happened**

- **The list is empty.** Steps 20 and 21 wrote somewhere else. Check the bucket name.
- **The list command is denied.** The deploy identity has no bucket-level action. Go back to
  Step 11.
- **The curl returns 200.** Something has made the bucket public. Go back to Step 8, then check
  with `aws s3api get-bucket-policy --bucket <BUCKET> --profile <SETUP_PROFILE>` for a policy
  nobody meant to attach.

---

# Day 3: the distribution

## Step 23. Create the origin access control

This is the credential CloudFront presents to S3. It is what the bucket will trust, and it is
the difference between criterion 3 satisfied and a public bucket that happens to work.

Save this as `deploy/cloudfront/oac.json`:

```json
{
  "Name": "etp-<team>-ui-oac",
  "Description": "ETP trading UI origin access control",
  "SigningProtocol": "sigv4",
  "SigningBehavior": "always",
  "OriginAccessControlOriginType": "s3"
}
```

**Do**

```bash
aws cloudfront create-origin-access-control \
  --origin-access-control-config file://deploy/cloudfront/oac.json \
  --profile <SETUP_PROFILE>
```

**Success looks like** a response whose `OriginAccessControl.Id` starts with `E`. Write it on the
record sheet as `<OAC_ID>`.

**If that is not what happened**

- **`OriginAccessControlAlreadyExists`.** Somebody made it. Find the id with
  `aws cloudfront list-origin-access-controls --query 'OriginAccessControlList.Items[].[Id,Name]'
  --output text --profile <SETUP_PROFILE>`.
- **`InvalidArgument`.** A field is misspelled or the case is wrong. `sigv4` and `always` are
  lowercase; the other three values are as written above.
- **`Error parsing parameter`.** The JSON file is not valid, or the `file://` path is not
  relative to where you are standing.

## Step 24. Write the distribution configuration

**Do** save this as `deploy/cloudfront/distribution.json`, with your own values substituted. It
is committed, and it is the file an assessor reads to see how the distribution was configured.

```json
{
  "CallerReference": "etp-<team>-ui-<YYYYMMDD>",
  "Comment": "ETP trading UI",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "etp-ui-origin",
        "DomainName": "<BUCKET>.s3.<REGION>.amazonaws.com",
        "S3OriginConfig": { "OriginAccessIdentity": "" },
        "OriginAccessControlId": "<OAC_ID>",
        "ConnectionAttempts": 3,
        "ConnectionTimeout": 10
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "etp-ui-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] }
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      {
        "ErrorCode": 403,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 10
      },
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 10
      }
    ]
  },
  "PriceClass": "PriceClass_All"
}
```

Five of those fields are decisions rather than boilerplate, and you should be able to say why
each one is there.

| Field | Why |
|---|---|
| `DomainName` ending `.s3.<REGION>.amazonaws.com` | The bucket's REST endpoint, not its website endpoint. Website hosting stays off: it is a second, public front door with no HTTPS and no origin access control. |
| `OriginAccessControlId` with an empty `OriginAccessIdentity` | The origin is reached with the modern signed credential. The empty legacy field is required and stays empty. |
| `ViewerProtocolPolicy: redirect-to-https` | Criterion 1 is HTTPS. A viewer that arrives on plain HTTP is redirected rather than served. |
| `CachePolicyId` | The AWS managed CachingOptimized policy. Your own `Cache-Control` headers from Steps 20 and 21 are what actually differentiate the two families of file. |
| `CustomErrorResponses` | The deep-link fix. Read Step 28 before you decide it is decoration. |

**Success looks like** a file that `python3 -m json.tool deploy/cloudfront/distribution.json`
parses without complaint, with no angle brackets left in it.

**If that is not what happened**, the parser names the line. The usual causes are a trailing
comma and a placeholder left unreplaced.

## Step 25. Create the distribution

**Do**

```bash
aws cloudfront create-distribution \
  --distribution-config file://deploy/cloudfront/distribution.json \
  --profile <SETUP_PROFILE>
```

**Success looks like** a large JSON response. Three fields matter:

```json
{
    "Distribution": {
        "Id": "E...",
        "Status": "InProgress",
        "DomainName": "d111111abcdef8.cloudfront.net"
    }
}
```

Write `Id` on the record sheet as `<DIST_ID>` and `DomainName` as `<DIST_DOMAIN>`. `InProgress`
is the expected status: the distribution is being pushed to the edge network.

**If that is not what happened**

- **`InvalidArgument: The parameter Origin DomainName does not refer to a valid S3 bucket.`** The
  origin domain is misspelled, or names the website endpoint (`s3-website`) rather than the REST
  endpoint.
- **`InvalidArgument` naming a field.** A required field is missing or has the wrong type.
  `ResponseCode` is a string in quotes; `ErrorCode` is a number without them.
- **`NoSuchOriginAccessControl`.** `<OAC_ID>` is wrong. Go back to Step 23.
- **`DistributionAlreadyExists`.** The `CallerReference` has been used before, on a distribution
  that already exists. The message names it. Use that one, or change the reference and create a
  second only if you meant to.
- **`AccessDenied`.** The setup identity cannot create distributions in this account. Take it to
  the alumni.

## Step 26. Wait, and use the wait

**Do**

```bash
aws cloudfront wait distribution-deployed --id <DIST_ID> --profile <SETUP_PROFILE>
```

**Success looks like** the command returning with no output. That means the status is `Deployed`.

This takes minutes rather than seconds. Three to ten is typical, longer is not alarming, and
nothing you do makes it faster. The waiter polls once a minute and gives up after roughly
thirty-five minutes.

Use the time. Step 27 does not need the distribution to be deployed, only to exist, and Step 17
can be finished now that you have `<DIST_DOMAIN>`. Do both while this runs, in another terminal.

**If that is not what happened**

- **`Waiter DistributionDeployed failed: Max attempts exceeded`.** Check the status directly with
  `aws cloudfront get-distribution --id <DIST_ID> --query 'Distribution.Status' --output text
  --profile <SETUP_PROFILE>`. If it still says `InProgress`, run the waiter again. If it has said
  `InProgress` for over an hour, raise it with the alumni.
- **The command exits immediately.** Either it was already deployed, or `<DIST_ID>` is wrong.
  Check the status directly.

## Step 27. Let the bucket trust the distribution, and nothing else

Save this as `deploy/cloudfront/bucket-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<BUCKET>/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::<ACCOUNT_ID>:distribution/<DIST_ID>"
        }
      }
    }
  ]
}
```

**Do**

```bash
aws s3api put-bucket-policy \
  --bucket <BUCKET> \
  --policy file://deploy/cloudfront/bucket-policy.json \
  --profile <SETUP_PROFILE>

aws s3api get-bucket-policy --bucket <BUCKET> --profile <SETUP_PROFILE>
```

**Success looks like** no output from the first command and the policy read back by the second.

Read what this policy says, because it is criterion 3 in one statement. The bucket grants read of
its objects to the CloudFront service, and only when the request comes from one named
distribution. Not to the internet, and not to every distribution in AWS.

**If that is not what happened**

- **`AccessDenied` on `put-bucket-policy`.** You have written a policy that grants public access,
  and `BlockPublicPolicy` from Step 8 has refused it. That is the block doing its job. Check that
  `Principal` is the service and not `"*"`, and that the `Condition` is present.
- **`MalformedPolicy: Policy has invalid resource`.** The bucket ARN has no `arn:aws:s3:::`
  prefix, or is missing the `/*`.
- **`MalformedPolicy: Invalid principal in policy`.** `cloudfront.amazonaws.com` is misspelled.
- **`NoSuchBucketPolicy` from the second command.** The first one did not apply.

## Step 28. Load it, then load a deep link

**Do**

```bash
curl -sI https://<DIST_DOMAIN>/ | head -n 3
curl -s https://<DIST_DOMAIN>/ | head -c 200
curl -s -o /dev/null -w '%{http_code}\n' https://<DIST_DOMAIN>/dashboard
```

Then open `https://<DIST_DOMAIN>/` in a browser, navigate to a route inside the application, and
press refresh.

**Success looks like** `HTTP/2 200` with `content-type: text/html`, a body containing
`<app-root` or your root element, `200` from the deep-link probe, and a refresh on an inner
route that renders the application rather than an error.

Why the deep link is a step and not a footnote: behind an origin access control, a request for a
key that does not exist comes back as `403`, not `404`, because an anonymous caller is not
permitted to learn whether an object exists. Your Angular router owns `/dashboard` and
`/orders/42`. There is no object at either key. Without the `CustomErrorResponses` from Step 24,
every refresh on every route but the root returns an error page, and the first person to try it
is whoever you sent the link to.

**If that is not what happened**

- **`403` with `<Code>AccessDenied</Code>` on the root.** The bucket policy is missing, its
  `AWS:SourceArn` does not match this distribution, or the distribution has no
  `OriginAccessControlId`. Check all three, in that order.
- **`403` on `/dashboard` and `200` on the root.** `CustomErrorResponses` did not make it into
  the configuration. Fix it in place: read the current configuration and its ETag with
  `aws cloudfront get-distribution-config --id <DIST_ID> --query 'DistributionConfig' --output
  json > deploy/cloudfront/current.json` and
  `aws cloudfront get-distribution-config --id <DIST_ID> --query 'ETag' --output text`, add the
  block from Step 24 to `current.json`, then
  `aws cloudfront update-distribution --id <DIST_ID> --distribution-config
  file://deploy/cloudfront/current.json --if-match <ETAG>`, then wait as in Step 26.
- **`PreconditionFailed` on that update.** The ETag was stale because somebody else changed the
  distribution. Read it again and retry.
- **`404` on the root.** `DefaultRootObject` is not `index.html`, or `index.html` is not in the
  bucket. Check with Step 22.
- **Nothing answers, or the connection times out.** The distribution has not finished deploying.
  Go back to Step 26.
- **The page loads and the console shows `Unexpected token '<'`.** An asset the page references
  is not in the bucket, so the 404 mapping returned `index.html` where JavaScript was expected.
  Run Steps 20 and 21 again and check the object list.

## Step 29. Add the invalidation permission

The distribution now exists, so the third statement in the deploy policy can name it.

**Do** add the `InvalidateTargetDistribution` statement from
`sprint-11-cloud-deploy/iam/policy-skeleton.json` to `deploy/iam/deploy-policy.json`, with the
resource ARN `arn:aws:cloudfront::<ACCOUNT_ID>:distribution/<DIST_ID>`. Work out the actions the
same way as in Step 11: one to create an invalidation, and one to read its status if your script
waits for it, which the next step does.

```bash
aws iam put-user-policy \
  --user-name <DEPLOY_USER> \
  --policy-name etp-deploy \
  --policy-document file://deploy/iam/deploy-policy.json \
  --profile <SETUP_PROFILE>
```

**Success looks like** no output. The inline policy is replaced in place, so the two S3
statements you already had are still there only if they are still in the file. Check the file
before you send it.

**If that is not what happened**

- **`MalformedPolicyDocument`.** The CloudFront distribution ARN has no region in it: it is
  `arn:aws:cloudfront::<ACCOUNT_ID>:...` with two colons together. That is correct and not a
  typo.
- **The next step is denied.** Read the action it names and add that one.

## Step 30. Invalidate

**Do**

```bash
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --paths '/index.html' \
  --profile <DEPLOY_PROFILE>
```

Take the `Invalidation.Id` from the response, then:

```bash
aws cloudfront wait invalidation-completed \
  --distribution-id <DIST_ID> \
  --id <INVALIDATION_ID> \
  --profile <DEPLOY_PROFILE>
```

**Success looks like** a response with `"Status": "InProgress"` and an id starting with `I`, then
the waiter returning silently after a minute or two.

Only `/index.html` needs invalidating. The hashed assets are content-addressed: a new build
produces new filenames, which no edge has ever cached, so there is nothing stale to clear.

**If that is not what happened**

- **`AccessDenied` naming `cloudfront:CreateInvalidation`.** Step 29 did not apply, or the
  distribution ARN does not match. Fix and repeat.
- **The waiter is denied.** Your script reads the invalidation status, so the policy needs the
  action that reads it. Add it.
- **You wrote `--paths /*` without quotes and the command invalidated filenames from your
  working directory.** The shell expanded the glob. Quote it: `--paths '/*'`. It is worth knowing
  that a wildcard invalidation is one path for billing while a thousand named files are a
  thousand, and that the first thousand paths a month are free.
- **`TooManyInvalidationsInProgress`.** You have several in flight. Wait for them to finish.

At the end of Day 3 the application is on the internet, over HTTPS, from a private bucket. What
is missing is that any of it is repeatable.

---

# Day 4: automation, verification and the link

## Step 31. Assemble the deploy script

Everything the deploy does, you have now done by hand. This step turns those commands into one
entry point, which is criterion 4.

**Do** write `deploy/deploy-ui.sh`, executable, containing in order:

1. `#!/usr/bin/env bash` and `set -euo pipefail`, so a failed build never reaches the upload.
2. Configuration read from the environment or from a committed non-secret file: the bucket, the
   distribution id, the region, the profile, the dist directory. No credentials in the script.
3. The build from Step 18, starting at `npm ci`, not at whatever is in `dist/`.
4. The two uploads from Steps 20 and 21, hashed assets first and `index.html` second.
5. The invalidation from Step 30, on `/index.html`, waiting for it to complete.
6. A final line printing `https://<DIST_DOMAIN>/`, so the person who ran it knows where to look.

```bash
chmod +x deploy/deploy-ui.sh
```

If the script grows past one file, keep one entry point that calls the others. Two copies of
the same three stages drift apart within a week.

**Success looks like** a script that a member of the team who has not been driving can run,
unaided, from a clean checkout, with only their AWS profile configured.

**If that is not what happened**

- **The script has a key in it.** Take it out and rotate the key. It goes in your AWS profile,
  not in a file anybody can clone.
- **The script only works from one directory.** Resolve paths from the script's own location
  rather than from the caller's working directory.
- **You cannot decide where the script should live.** Put it at `deploy/deploy-ui.sh`. You can
  run it the moment it exists, which is the point of today.

## Step 32. Run it twice

**Do**

```bash
./deploy/deploy-ui.sh
```

Load `https://<DIST_DOMAIN>/` in a browser and confirm the application is there. Then:

```bash
./deploy/deploy-ui.sh
```

Load it again.

**Success looks like** two runs that both exit zero, and a working site after each. A second run
against the same commit leaves the deployment in the same state as the first. That is the
property that makes a deploy something you can do on a Friday afternoon.

**If that is not what happened**

- **The second run fails where the first passed.** Something in the script assumes an empty
  bucket or a first-time creation. A deploy creates nothing; it only writes objects and one
  invalidation.
- **The site breaks between the two runs.** Almost always ordering: `index.html` went up before
  the assets it points at, or `--delete` removed the previous build's assets while a browser was
  still holding the old `index.html`. Upload assets first, index second, and invalidate the
  index. For a training deployment that is the accepted trade; a production deployment keeps the
  previous assets for a grace period, and saying so is a good answer to a question about it.
- **The build fails on a teammate's machine but not yours.** That is what `npm ci` and a
  committed lock file are for. Check both are in the script and in the repository.

## Step 33. Check the deployment from outside

Everything here is checked the way a customer would check it, over the network, holding no AWS
credentials.

**Do**

```bash
curl -sSI "https://<DIST_DOMAIN>/"
curl -sS "https://<BUCKET>.s3.<REGION>.amazonaws.com/index.html"
curl -sS "https://<BUCKET>.s3-website-<REGION>.amazonaws.com/"
```

Then fetch the JavaScript files your deployed `index.html` references and run the Sprint 9
secret patterns over them, the same grep as Step 19.

**Success looks like** 200 and your application from the distribution, access denied from both
bucket endpoints, and no output at all from the grep.

**If that is not what happened**

- **The distribution answers oddly on the first attempt.** Try again before debugging it. A
  distribution that has just changed and an invalidation in flight both produce odd answers for
  a few minutes.
- **A bucket endpoint answers with content.** The bucket is public. Go back to Step 12 and
  Step 22: the answer is an origin access control and a bucket policy naming the distribution,
  not a public bucket.
- **A bucket endpoint reports 404 `NoSuchBucket` or a redirect.** The bucket name or the region
  in the URL is wrong. You are addressing something that is not your bucket.
- **The grep names a file.** The bundle every visitor downloads carries a secret. Rotate it
  today, take it out of the source, and redeploy.

## Step 34. Verify the authenticated flows against the deployed URL

This is criterion 5, and it is the one a rendering page does not satisfy.

**Do** on a machine with the local stack running, in a Chromium-based browser or Firefox:

1. Open `https://<DIST_DOMAIN>/`. Not `localhost:4200`. Close the development server so you
   cannot be looking at it by accident.
2. Sign in as a real user.
3. Place an order.
4. Watch it reach the blotter with a status.
5. Refresh the page on an inner route and confirm you stay signed in and on that route.
6. Keep the browser console open throughout and read what appears in it.

**Success looks like** all six, from the CloudFront domain, with an empty console.

**If that is not what happened**

- **The sign-in request is blocked by CORS.** The service has not been told about the new origin.
  Go back to Step 17. The console names the header that was missing.
- **The request never leaves the browser and the console says the content is mixed or
  insecure.** An HTTPS page cannot call a plain HTTP address on another host. Chromium and
  Firefox make an exception for `http://localhost`, which is why Step 15 chose it. Safari does
  not. Use Chrome, Edge or Firefox for this verification, and record which one.
- **The call goes to the wrong address.** The bundle carries a build-time value. Change the
  environment file from Step 16, run Step 32, and try again. Do not edit the deployed bundle.
- **Sign-in succeeds and a later call fails with 401.** The token is not being attached from this
  origin. Check that your interceptor is not conditioned on the host, and that the browser is not
  dropping a cookie because the site is now cross-site.
- **Everything works on your machine and nothing works on a teammate's.** Their stack is not
  running, or is running on different ports. That is the cost named in Step 15, and it is what
  you say when you share the link.

Write down, in the decision log, what you did and which browser you did it in. Nobody watches
this happen, so the record of it is the evidence.

## Step 35. Confirm the bucket is still the only way in

**Do**

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<BUCKET>.s3.<REGION>.amazonaws.com/index.html
curl -s -o /dev/null -w '%{http_code}\n' http://<BUCKET>.s3-website.<REGION>.amazonaws.com/
curl -s -o /dev/null -w '%{http_code}\n' http://<DIST_DOMAIN>/
```

**Success looks like** `403` from the REST endpoint, `404` or no answer from the website
endpoint, and `301` or `302` from plain HTTP on the distribution. A bucket with no website
configuration answers its website endpoint with `404 NoSuchWebsiteConfiguration`, which is the
right answer here.

**If that is not what happened**

- **`200` from either bucket endpoint.** The bucket is public and criteria 2 and 3 both fail,
  whatever the site looks like. Go back to Step 8 and read the bucket policy.
- **`200` from plain HTTP on the distribution.** `ViewerProtocolPolicy` is `allow-all`. Change it
  to `redirect-to-https` with the update flow from Step 28.
- **The website endpoint answers with an S3 error page rather than nothing.** Static website
  hosting is enabled on the bucket. Disable it with
  `aws s3api delete-bucket-website --bucket <BUCKET> --profile <SETUP_PROFILE>`. The distribution
  reads the REST endpoint, so nothing you need depends on it.

## Step 36. Commit everything that explains the deployment

Assessment is asynchronous. Nobody will be at your desk to ask how the bucket became private, so
the repository has to answer it.

**Do** commit, on a branch, reviewed and merged as usual:

- `deploy/deploy-ui.sh`.
- `deploy/iam/deploy-policy.json`, filled in.
- `deploy/cloudfront/oac.json`, `distribution.json` and `bucket-policy.json`.
- The Angular environment change from Step 16.
- The cross-origin change from Step 17.
- Decision-log entries for Step 15 and Step 34.

Then search the merged branch, working tree and history both, for anything key-shaped one last
time.

**Success looks like** nothing found.

**If that is not what happened**

- **The history search finds an access key id.** A key is in a commit even though it is not in
  the file today. Deactivate and delete that key in IAM now, then agree as a team what to do
  about the history, and record both actions. Rotation is not optional either way.
- **A file you meant to commit is ignored.** Check `.gitignore`. `deploy/` should not be ignored;
  a `.env` should be.

## Step 37. Share the link

**Do** post to the cohort channel, once, with four things:

- The URL: `https://<DIST_DOMAIN>/`.
- What works from a cold browser anywhere: the application loads over HTTPS.
- What needs a local stack: sign-in and everything behind it, because the API base URL points at
  `localhost` by the decision in Step 15.
- The date you will tear it down.

**Success looks like** the link posted and at least one person outside your team confirming the
page loads for them.

**If that is not what happened**

- **Somebody reports the page does not load.** Ask for the exact URL they used and the status
  they saw. A trailing path they typed is the usual answer; an actual failure shows up in
  Step 33 too.
- **Somebody reports they cannot sign in.** That is expected and it is the second bullet. Do not
  change the deployment for it.

The week's deliverable is now complete: the build is on a private bucket behind CloudFront, the
cycle is one command, it is verified from the outside and from a browser, and the link is
shared. Assessment happens against the acceptance criteria in `README.md`, from what is deployed
and what is committed.

---

# After the week: teardown

Do this once your assessment is confirmed, and not before. Then check it is gone rather than
assuming. A bucket and a distribution left running is a bill that arrives quietly for months.

## Step T1. Disable the distribution

**Do**

```bash
aws cloudfront get-distribution-config --id <DIST_ID> \
  --query 'DistributionConfig' --output json --profile <SETUP_PROFILE> \
  > deploy/cloudfront/teardown.json

aws cloudfront get-distribution-config --id <DIST_ID> \
  --query 'ETag' --output text --profile <SETUP_PROFILE>
```

Change `"Enabled": true` to `"Enabled": false` in `deploy/cloudfront/teardown.json`, then:

```bash
aws cloudfront update-distribution --id <DIST_ID> \
  --distribution-config file://deploy/cloudfront/teardown.json \
  --if-match <ETAG> --profile <SETUP_PROFILE>

aws cloudfront wait distribution-deployed --id <DIST_ID> --profile <SETUP_PROFILE>
```

**Success looks like** the update returning the distribution with `"Enabled": false`, and the
waiter returning silently. A distribution cannot be deleted while it is enabled.

**If that is not what happened**

- **`PreconditionFailed`.** The ETag is stale. Read it again and retry.
- **The waiter takes a long time.** Disabling propagates to the edge like any other change. Wait
  it out.

## Step T2. Delete the distribution

**Do**

```bash
aws cloudfront get-distribution-config --id <DIST_ID> \
  --query 'ETag' --output text --profile <SETUP_PROFILE>

aws cloudfront delete-distribution --id <DIST_ID> --if-match <ETAG> --profile <SETUP_PROFILE>
```

**Success looks like** no output.

**If that is not what happened**

- **`DistributionNotDisabled`.** T1 has not finished. Wait and retry.
- **`InvalidIfMatchVersion`.** The ETag changed when you disabled it. Read the current one, which
  is what the first command above is for.

## Step T3. Empty and delete the bucket

**Do**

```bash
aws s3 rm s3://<BUCKET>/ --recursive --profile <SETUP_PROFILE>
aws s3api delete-bucket --bucket <BUCKET> --region <REGION> --profile <SETUP_PROFILE>
```

**Success looks like** one `delete:` line per object and no output from the second command.

**If that is not what happened**

- **`BucketNotEmpty`.** The recursive delete missed something. Run it again and then
  `aws s3api list-objects-v2 --bucket <BUCKET> --profile <SETUP_PROFILE>` to see what is left.
- **`AccessDenied` on the delete.** You are using the deploy profile. Use the setup profile: the
  deploy identity is not permitted to delete buckets, which is Step 14 still working.

## Step T4. Delete the origin access control

**Do**

```bash
aws cloudfront get-origin-access-control --id <OAC_ID> \
  --query 'ETag' --output text --profile <SETUP_PROFILE>

aws cloudfront delete-origin-access-control --id <OAC_ID> --if-match <ETAG> \
  --profile <SETUP_PROFILE>
```

**Success looks like** no output.

**If that is not what happened**

- **`OriginAccessControlInUse`.** The distribution still exists. Finish T2 first.

## Step T5. Delete the deploy identity

**Do**

```bash
aws iam list-access-keys --user-name <DEPLOY_USER> --profile <SETUP_PROFILE>
aws iam delete-access-key --user-name <DEPLOY_USER> --access-key-id <KEY_ID> \
  --profile <SETUP_PROFILE>
aws iam delete-user-policy --user-name <DEPLOY_USER> --policy-name etp-deploy \
  --profile <SETUP_PROFILE>
aws iam delete-user --user-name <DEPLOY_USER> --profile <SETUP_PROFILE>
```

**Success looks like** the key listed, then no output from the three deletions.

**If that is not what happened**

- **`DeleteConflict`.** The user still has a key or a policy attached. The order above removes
  both first; run whichever you skipped.

## Step T6. Check it is gone

**Do**

```bash
aws s3api head-bucket --bucket <BUCKET> --profile <SETUP_PROFILE>
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].[Id,DomainName]' --output text --profile <SETUP_PROFILE>
aws iam list-users --query 'Users[].UserName' --output text --profile <SETUP_PROFILE>
```

**Success looks like** a `404` error from `head-bucket`, no line for `<DIST_ID>` in the
distribution list, and no `<DEPLOY_USER>` in the user list. Three absences, checked rather than
assumed.

**If that is not what happened**, whatever is still listed is still costing something. Go back to
the step that was meant to remove it and read the error it gives you now.
