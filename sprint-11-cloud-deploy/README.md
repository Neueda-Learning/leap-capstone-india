# Cloud week: the front end leaves localhost

Nine weeks of platform ran on your laptops. That is not a criticism of the build. It is the
reason nobody outside your team has ever used it, and it is the one property a trading platform
cannot keep. Somebody has to be able to open a browser, on a machine you have never touched, and
reach the application over a link you sent them.

This week you put the front end somewhere that link works from, automate the way it gets there,
verify it from the outside, and share the link with the cohort.

This folder is called `sprint-11-cloud-deploy` so that its name matches the same week in every
other Leap cohort; this cohort has no Sprint 11, and this is the cloud week that runs after the
capstone.

## Who runs this week, and what follows from that

Fidelity delivers this week as experiential learning, over four and a half days, with Fidelity
alumni on hand. There are no Neueda instructors in the room and no live Neueda support. Nobody
is going to notice that your team is stuck on a step and walk over.

So the runbook is the instructor. `RUNBOOK.md` is the whole week in order, from an empty AWS
account to a verified deployment, and every step in it says three things: what to run, what
success looks like, and what to do when that is not what happened. It is written to be followed
literally, on paper if you print it. Work through it in sequence rather than mining it for
commands, because several steps exist only so that a later failure is legible when it arrives.

The alumni are there for the judgement calls the runbook cannot make: which of two options suits
what your team already built, whether what is on your screen is the state the runbook describes,
whether a decision you took would survive contact with a production estate. Take those to them.
Take the steps to the runbook first.

The material is fixed for the week. If you find something in it that is wrong, write down what
you found and what you did instead, keep going, and hand that note in with the deployment. A
correction is useful. A team stopped for a day waiting for one is not.

## Do not start this week with a broken Sprint 10

The prerequisite for this week is a Sprint 10 build that passes its own tests and a local stack
that starts cleanly. That is a gate, not a recommendation.

Every verification in this week runs against the platform you already have. Day 4 asks you to
sign in, place an order and watch it fill, driven from a page served by a CDN. If the stack
behind that page is broken, you will be debugging Sprint 10 with an AWS distribution in front of
it, and you will not be able to tell which layer is at fault. Fix the platform first, on the
Monday morning if that is what it takes, and treat the day you spend on it as cheaper than the
two days it costs later.

Confirm both before Step 1 of the runbook. The stack starts, and every route your four Sprint 10
modules added still answers a real token. Start it the way your team's orchestration starts it,
and check that every container reached a running state.

Nothing this week stops, restarts or reconfigures a container you did not start yourself. The
deployment changes what serves the browser, not what the browser talks to.

## The target architecture

Three components, and one rule that fixes how they fit together.

| Component | What it is |
|---|---|
| An S3 bucket | Holds the built Angular application. Private. Blocks all public access. Never addressed directly by a browser. |
| An origin access control | The credential CloudFront presents to S3 when it fetches an object. It is what the bucket trusts. |
| A CloudFront distribution | The public face. Terminates TLS, serves over HTTPS, caches at the edge, and is the only reader the bucket accepts. |

The rule is that the bucket is unreachable except through the distribution. A browser that
resolves the bucket's own endpoint gets access denied. A browser that loads your
`*.cloudfront.net` domain gets the application. That is not a detail of configuration, it is the
shape being assessed.

Only the Angular application is deployed. Postgres, Kafka, the Trade REST API, the Auth service,
the Trade Executor and the analytics pipeline stay in your local stack, on your machines,
exactly as they are. The Trade REST API hosts your four extensions and the domain package, and
the Trade Executor runs the market-data poller. Deploying any of it is out of scope for this programme.

S3 will host a static site on its own: enable website hosting, attach a bucket policy granting
`s3:GetObject` to `"Principal": "*"`, and the application loads. It works, and it fails this
week with a working site on screen. The bucket endpoint serves over plain HTTP as well as HTTPS,
so a public bucket puts your login form on an unencrypted URL. Everything in the bucket becomes
world-readable to anyone who guesses the name, not only the files you meant to publish. And no
cache policy, compression setting or error-page rule can sit in front of an origin that is being
read directly, which removes every decision this week asks you to take.

The principle underneath the three reasons is worth more than the reasons. Origin access control
means the origin trusts exactly one caller, named and verified. A public policy means the origin
trusts the internet and hopes the only thing pointing at it is your CDN. The first is a control.
The second is a convention.

## Region, guardrails and cost

Before any hands-on cloud work, a Fidelity platform SME briefs the cohort on how Fidelity
governs its own AWS estate. That session is a briefing and not a lab. You deploy nothing to
anything belonging to Fidelity, and you work only in the training account you are given. Attend
it first: the reason the criteria below are shaped the way they are is a good deal clearer
afterwards.

CloudFront is a global edge network, so the region you pick only decides where the bucket lives.
Use `ap-south-1` and use it everywhere for the rest of the week. Region names appear in bucket
endpoints, in ARNs and in CLI calls, and a distribution pointed at a bucket in a region you have
half-migrated away from produces errors that read like something else entirely. If a call
reports that your bucket must be addressed using a different endpoint, you have two regions in
play, not a broken bucket.

The AWS surface for the whole week is small: `aws s3api` and `aws s3` for the bucket and the
upload, `aws cloudfront` for the origin access control, the distribution and the invalidation,
`aws iam` for the deploy user and its policy, and `aws sts get-caller-identity` when you need
your own account id. Nothing else in the CLI is in scope, and nothing else in AWS is either.

The deployment costs close to nothing: one Angular build is a few megabytes, and a cohort
generates a request volume that sits inside the free usage allowances. Confirm the current terms
rather than trusting that sentence, because they change. The real cost risk is forgetting the
thing exists. A bucket and a distribution per team, left running, is a bill that arrives quietly
for months. Tear it down on the day you are told to, and check it is gone rather than assuming.

## IAM scoping

Two identities are in play and they must not be the same one.

The **setup identity** creates the bucket, the origin access control, the distribution and the
deploy user. It is broad by necessity, it is used by a human, by hand, and it is used once.

The **deploy identity** is what the automation runs as. It can write objects into one named
bucket and create an invalidation on one named distribution. It cannot create a bucket, cannot
read another bucket, cannot touch another distribution, and cannot create a user. If those
credentials were pasted into a public issue tomorrow, the worst an attacker could do is replace
the contents of a training front end. That containment is the point of the exercise.

`iam/policy-skeleton.json` is the shape, not the answer. It has three statements, the resource
ARNs are placeholders you replace with your own bucket name, account id and distribution id, and
the actions are left for you to work out:

| Statement | What it has to permit, and why |
|---|---|
| `ListTargetBucket` | The bucket-level action a sync needs in order to work out what is already there and what has to change. The resource ARN has no `/*` on the end: this is a permission on the bucket, not on objects in it. |
| `WriteObjectsInTargetBucket` | The object-level actions an upload needs. Work them out from your own upload command, including what happens when a file present in the last build is absent from this one. The ARN ends `/*` because these act on objects. |
| `InvalidateTargetDistribution` | Creating an invalidation, and reading its status if your script waits for it to finish. Scoped to your one distribution ARN. |

Working the actions out is part of criterion 6, and the runbook shows you how to work them out
rather than what to type: you derive them from the commands you actually run, then let AWS
correct you, because an `AccessDenied` from the CLI names the exact action it wanted. Do not
short-circuit that with `"Action": "s3:*"` or `"Resource": "*"`. A policy that grants everything
fails the criterion whether or not the deploy works.

Two rules on the credentials themselves, and neither is negotiable.

**No long-lived key goes into the repository, ever, in any branch.** Not in a config file, not
in a `.env` that slipped past `.gitignore`, not in a comment, not in a screenshot pasted into a
document, not in a test fixture. Search your working tree for the shape of an access key, and
search the recorded history of this folder as well, because a key that was committed and then
deleted is still a disclosed key.

**Store the pair where the thing that needs it can read it and nobody else can.** Configure a
named AWS CLI profile so that the keys live in `~/.aws/credentials` and never in your shell
history, and let the script pick that profile up by name. Non-secret identifiers, the region,
the bucket name and the distribution id, are arguments or environment variables rather than
secrets: treating them as secrets only makes the real secrets harder to find.

## The deployment cycle as a contract

Deployment is one command. Not a sequence of commands in a teammate's shell history, not five
steps a person executes in order, and not a console upload.

That single entry point does three things, in this order:

1. **Build.** A clean, reproducible install and a production build of the Angular application.
2. **Upload.** The build output into the bucket, so that the bucket ends up holding this build
   and not a mixture of this build and the last one.
3. **Invalidate.** The CloudFront cache, so that the next request gets what you just uploaded
   rather than what the edge is still holding.

The third is the one teams skip, and skipping it produces the most expensive bug of the week:
you deploy a fix, you load the link, you see the old application, and you spend an hour
debugging code that is not running.

Step two carries a decision worth taking deliberately. Your build produces two families of file.
The hashed assets, `main.<hash>.js` and its neighbours, are content-addressed, so a given
filename never changes content and can be cached for a year. `index.html` is not hashed and it
is the pointer to which hashed assets are current, so it must never be served stale. Set the
cache headers accordingly on upload and your invalidation shrinks to a single path.

**A second run must be safe.** Running your entry point twice, against the same commit, has to
leave the deployment in the same state as running it once, and it has to leave a working site
both times. Test that by running it twice and loading the site in between, not by reasoning
about it.

The entry point is a shell script. The runbook builds it from the commands you have already
run by hand, because you can run a script the moment you have written it.

## Verifying against the deployed front end

A page that renders is not a deployed application. The criterion is that the authenticated flows
work against the deployed URL: sign in as a real user, place an order, watch it reach the
blotter, all of it driven from the CloudFront domain rather than from `localhost:4200`.

That is where the architecture bites, and it is meant to. Your API is still on your machine and
the application is now served from an origin that is not your machine. Two consequences follow
and you own both.

**The API base URL.** The bundle contains whatever address it was built with. Built one way, the
deployed page asks a host with nothing on it. Built another way, it asks a host only the person
who built it can reach. Decide what the deployed build points at, get that address into the
build without it becoming a value somebody edits by hand before every deploy, and write the
choice down. Sprint 9 gave you Angular environments, and the same rule about secrets applies: an
address is not a secret, a key is.

**Cross-origin requests.** The page's origin is now your distribution domain, over HTTPS. Your
Trade REST API and your Auth service have only ever been asked for data by a page served from
the same machine that served them. They are about to be asked by a page served from somewhere
else, by a browser that will not hand the response to your JavaScript unless the service says it
may. Work out what changes, where, whether allowing every origin is acceptable for a service
holding customer positions, and what the mixed-content rule does to an HTTPS page calling a
plain HTTP API.

Neither has a single right answer and both have several wrong ones. The runbook gives you a
route through both that works from the machines you already have, names what that route costs,
and names the alternatives. Take the route, record the decision in your decision log, and expect
the assessment to read it.

## How the week closes

Day 4 ends with the link shared with the cohort: the `https://<distribution>.cloudfront.net`
URL, posted where everyone can reach it, with one line on what works from a cold browser and one
line on what needs the local stack running. That is the deliverable, and sharing it is part of
it. The demonstration of the platform itself happened at the end of week 9, so there is no panel
this week and nothing to rehearse.

Assessment is asynchronous, against the acceptance criteria below, from what is deployed and
what is committed. Nobody watches you deploy. That raises the value of two things: a `README` or
decision-log entry that says what you chose and why, and a repository state where the deploy
entry point and the policy documents are all committed and all agree with each other. An
assessor who cannot tell how the bucket became private reads it as not proven.

Tear down after your assessment is confirmed, not before and not weeks later. The runbook's
final section deletes the distribution, the bucket, the origin access control and the deploy
user, in that order, and then checks each one is gone.

## What is in this folder

```
README.md                 this brief
RUNBOOK.md                the week, in order, with the failure modes
iam/policy-skeleton.json  the shape of the deploy policy, ARNs as placeholders
```

Your deployment entry point does not live here. A script belongs at a sensible path in the
repository, and `deploy/deploy-ui.sh` is the one the runbook uses. Say where you put it in the
decision-log entry that covers the deployment, because nobody is in the room to ask.

## Acceptance criteria

1. The application is reachable over HTTPS through the CloudFront distribution.
2. The S3 bucket is private and returns access denied when it is addressed directly.
3. Origin access control is configured. A public bucket policy does not satisfy this, whether or
   not the site loads.
4. Deployment is a single script covering build, upload and invalidation.
5. The authenticated flows are verified against the deployed front end.
6. The IAM user or role is scoped to the bucket and the distribution only, and no long-lived key
   is in the repository.

## Evaluation

This week contributes 5 marks to the 100-mark Capstone assessment. The runbook and the policy
skeleton are inputs. Marks are awarded for the deployment, automation and evidence the team
produces.

| Criterion | Marks |
|---|---:|
| Private S3 origin delivered through CloudFront with origin access control | 2 |
| Working authenticated journey from the deployed front end | 1 |
| Repeatable deployment and invalidation entry point | 1 |
| Scoped IAM, secret handling and recorded deployment decisions | 1 |
| **Sprint total** | **5** |

## What a person assesses

Every criterion this week is read from what you left behind. A URL that answers, a bucket that
refuses and a script that mentions three stages are the floor, and most of what the week is
assessed on happens in an AWS account nobody else holds credentials for.

Check what you can from outside before you submit, the way a customer would. Fetch your
distribution domain over HTTPS and confirm the answer is your Angular application rather than an
error page. Probe both of your bucket's own endpoints and confirm they refuse. Fetch the
JavaScript the deployed page references and run the Sprint 9 secret patterns over it: the bundle
CloudFront serves is the bundle every visitor gets. A distribution that has just been created
answers oddly until it reaches `Deployed`, and an invalidation in flight can serve you the
previous build, so an odd answer is worth a second attempt before it is worth an hour.

Everything the criteria turn on is read by a person, afterwards, from what you left behind.
Whether the bucket is private because of an origin access control or because nobody has made it
public yet. Whether the deploy policy is scoped to your two resources or to `*`. Whether the
deployment is one command or a runbook that one member of the team can execute. Whether a second
run leaves it working. Whether the authenticated flow ran from the deployed URL or from a
development server with the deployed URL open in another tab.

None of that is visible unless you write it down. Nobody is in the room to ask you, so the
decision log is the answer to the question you are not there to be asked.
