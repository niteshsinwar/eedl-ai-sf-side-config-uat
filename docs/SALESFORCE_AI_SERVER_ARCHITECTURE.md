# ISB AI Server Salesforce Architecture

This document explains the Salesforce side of the ISB AI Server integration. It intentionally treats the AI Server as an external HTTP service and does not depend on internal knowledge of the Python implementation.

## Purpose

The Salesforce package provides the CRM-side automation, job queue, operator controls, persistence objects, and callout services for AI-assisted document verification.

It supports two business workflows:

- Admissions application verification for `hed__Application__c`.
- EEDL / Executive Education verification for `Opportunity`.

The shared Salesforce platform is `AI_Server_Job__c`, scheduler dispatch, admin monitoring, retry/delete controls, and operational alerting. The verification result model remains separate by business vertical.

## Business Workflows

### Admissions

Admissions verification starts from a `hed__Application__c` record. It verifies application-related documents and applicant details, then persists results in `Application_Verification_Summary__c`.

Admissions-specific artifacts include:

- `Application_Verification_Summary__c`
- `DocumentChecklistItem.Application_Verification_Summary__c`
- `DocumentVerificationService`
- `ApplicationVerificationGateway`
- `ApplicationVerificationCalloutService`
- `AVSTrigger` and `AVSTriggerHandler`
- `EducationVerificationHandler`
- `EmploymentVerificationHandler`
- `TestScoreVerificationHandler`
- `ApplicationVerificationHandler`
- `Document_Verification_Issue__mdt`
- `Detail_Verification_Issue__mdt`

### EEDL / Opportunity

EEDL verification starts from an eligible `Opportunity` when it moves to the `Applicant` stage. It verifies identity/citizenship and education documents, then persists results in `EEDL_Verification_Summary__c`.

EEDL-specific artifacts include:

- `AI_Server_Job__c.Opportunity__c`
- `EEDL_Verification_Summary__c`
- `EEDLVerificationGateway`
- `EEDLVerificationCalloutService`
- `eedlManualVerificationButton`
- `EEDL_Verification_Summary_Record_Page`
- `EEDL_Verification_Summary__c` tab
- `AI_Server_ChokePoint__mdt.EEDL_Automated_Verification`

## Shared Data Model

### `AI_Server_Job__c`

This object is the shared Salesforce job envelope.

Important fields:

- `Application__c`: source record for admissions jobs.
- `Opportunity__c`: source record for EEDL jobs.
- `Job_ID__c`: external job identifier returned/maintained by the AI Server.
- `Status__c`: job state.
- `Message__c`: latest message or failure reason.
- `Progress_Details__c`: JSON progress snapshot.
- `Client_Fingerprint__c`: request fingerprint from the server side.
- `Logs__c`: long text JSON execution log with token/cost/attempt details.

Expected status lifecycle:

- `queued`
- `processing`
- `completed`
- `failed`

Some Apex code currently uses display-case values such as `Queued`, `Processing`, and `Failed`. Keep the picklist values and Apex comparisons aligned in the target org.

### `Application_Verification_Summary__c`

Admissions result object. It stores per-section verification output for the application.

Common result sections include:

- Personal Detail Analysis
- Education Analysis
- Employment Analysis
- Test Score Analysis
- Resume Detail Analysis
- Recommender Details Analysis
- Declaration Analysis

Important fields:

- `Application__c`
- `Contact__c`
- `Education_History__c`
- `Affiliation__c`
- `Test__c`
- `Verification_Analysis_Report__c`
- `Overall_Feedback__c`
- `Mismatched_Field_List__c`
- `Percentage_Confidence__c`
- `Issue_Category__c`
- `Document_Template_Comments__c`
- `Detail_Template_Comments__c`

### `EEDL_Verification_Summary__c`

EEDL result object. It stores verification outcomes for one Opportunity-level ID document or one related `Education__c` record.

Important fields:

- `Opportunity__c`
- `Education__c`
- `Education_Record_Id__c`
- `Record_Type__c`
- `Overall_Status__c`
- `Confidence_Score__c`
- `Summary_HTML__c`
- `Overall_Feedback__c`
- `Mismatched_Field_List__c`
- `Record_Last_Modified__c`
- `Doc_Last_Modified__c`
- `Last_Processed_At__c`

Expected record type values:

- `ID_Document`
- `Education`

## Feature Flags

Feature switches are stored in `AI_Server_ChokePoint__mdt`.

Known records:

- `Automated_Application_Verification`
- `Application_Checklist_Updation`
- `EEDL_Automated_Verification`

`EEDL_Automated_Verification` controls whether Opportunity stage changes enqueue EEDL verification jobs.

`Application_Checklist_Updation` controls whether completed admissions jobs update related checklist/task records from verification summaries.

## Automation Entry Points

### Admissions Manual Entry

`manualverificationbutton` calls:

```apex
ApplicationVerificationGateway.processApplicationFromLWC(applicationId)
```

The gateway:

1. Runs admissions checklist/detail automation.
2. Finds or creates `AI_Server_Job__c` for the application.
3. Sets status to queued.
4. Checks capacity through `AIserverAdminViewController.getActiveJobsCount()`.
5. If capacity exists, enqueues `ApplicationVerificationCalloutService`.
6. Otherwise leaves the job queued for `VerificationScheduler`.

### EEDL Manual Entry

`eedlManualVerificationButton` calls:

```apex
EEDLVerificationGateway.processOpportunityFromLWC(opportunityId)
```

The gateway:

1. Finds or creates `AI_Server_Job__c` for the Opportunity.
2. Sets status to queued.
3. Checks shared capacity.
4. If capacity exists, enqueues `EEDLVerificationCalloutService`.
5. Otherwise leaves the job queued for `VerificationScheduler`.

### EEDL Automatic Entry

`CEE_OpportunityTrigger` calls:

```apex
CEE_OpportunityTriggerHandler.triggerEEDLVerification(Trigger.new, Trigger.oldMap)
```

Automation criteria:

- Trigger context: after update.
- `StageName` changed to `Applicant`.
- Opportunity record type is in the eligible EEDL family.
- `AI_Server_ChokePoint__mdt.EEDL_Automated_Verification.Is_Enabled__c = true`.

Eligible Opportunity record type developer names:

- `CEE_Custom`
- `CEE_HR`
- `CEE_Open_LDP`
- `CEE_Open_SDP`
- `EE_Govt`
- `ExecEd_B2B`
- `ExecEdDefault`
- `Online_Program`

## Callout Services

Both callout services use Named Credential:

```text
AI_Server
```

The Named Credential owns the environment-specific host and path prefix. Apex code remains environment neutral.

### Admissions Callout

Class:

```apex
ApplicationVerificationCalloutService
```

Endpoint path:

```text
/api/v1/application/analyze
```

Request body:

```json
{
  "record_id": "APPLICATION_ID",
  "job_id": "AI_SERVER_JOB_RECORD_ID"
}
```

Only `record_id` is essential for the external service contract. `job_id` is included by Apex for traceability.

### EEDL Callout

Class:

```apex
EEDLVerificationCalloutService
```

Endpoint path:

```text
/api/v1/eedl/analyze
```

Request body:

```json
{
  "record_id": "OPPORTUNITY_ID"
}
```

### Callout Chaining

Both callout services process one job per queueable execution, then enqueue themselves for remaining jobs. This avoids doing too much work in a single queueable transaction and keeps callout behavior predictable.

## Scheduler

Class:

```apex
VerificationScheduler
```

Purpose:

- Runs every three minutes through a chained schedule.
- Checks active server capacity.
- Dispatches queued admissions jobs first.
- Uses remaining slots for queued EEDL jobs.
- Re-schedules itself after each run.

Capacity constant:

```apex
MAX_CONCURRENT_JOBS = 15
```

The scheduler uses:

```apex
AIserverAdminViewController.getActiveJobsCount()
```

That method currently counts Salesforce jobs with `Status__c = 'Processing'`. Keep status casing aligned with actual picklist values and server updates.

## Admin Panel

LWC:

```text
aiServerAdminView
```

Apex controller:

```apex
AIserverAdminViewController
```

Capabilities:

- Health check.
- Active queue view.
- Concluded job view.
- API transaction logs.
- Job logs and cost analytics.
- Retry failed jobs.
- Delete active or concluded jobs.
- Delete transaction logs.
- Show source flow as Admissions Application or EEDL Opportunity.

API paths used through Named Credential:

- `/api/v1/admin/health`
- `/api/v1/application/queue-overview`
- `/api/v1/application/status/{sourceRecordId}`
- `/api/v1/admin/processing-status/{sourceRecordId}`

The admin panel combines live server jobs with queued Salesforce jobs, then enriches source record names and links from either `hed__Application__c` or `Opportunity`.

## Admissions REST Data Provider

Class:

```apex
DocumentVerificationService
```

REST mapping:

```text
/services/apexrest/documentVerification/*
```

Supported path routes:

- `/documentVerification/application/{applicationId}`
- `/documentVerification/education/{educationLogId}`
- `/documentVerification/employment/{employmentLogId}`
- `/documentVerification/testscore/{testScoreId}`

The service routes requests to object-specific handlers and returns a verification data package containing Salesforce record data and document payload information.

## Admissions Post-Processing

`AIServerJobTriggerHandler` handles `AI_Server_Job__c` insert/update events.

Before insert/update:

- If job status becomes failed, checks error keywords.
- Can requeue transient failures.
- Can send operational alerts for server/network downtime or quota errors.

After insert/update:

- When status changes to completed, processes admissions jobs only.
- EEDL jobs are excluded from admissions checklist/task automation because they have `Opportunity__c` instead of `Application__c`.
- Updates admissions tasks and checklist items based on `Application_Verification_Summary__c`.

Protected behavior:

- Resume checklist items already marked `Accepted` are protected from automated downgrade.

## AVS Template Handling

`AVSTriggerHandler` runs on `Application_Verification_Summary__c`.

Before insert:

- Looks up `Document_Verification_Issue__mdt`.
- Looks up `Detail_Verification_Issue__mdt`.
- Copies matching template bodies onto the AVS record.

After update:

- Watches `Issue_Category__c`.
- If issue category is `Document`, updates matching `DocumentChecklistItem`.
- If issue category is `Details`, updates matching `Task`.
- If issue category is `Both`, updates both.

EEDL uses a separate summary object and does not participate in this AVS trigger.

## Failure Handling

### Callout Failure

If the external AI Server responds with a non-2xx status:

1. `ErrorLogHandler.createLog(...)` records request/response details.
2. The job is marked failed.
3. The scheduler/admin panel can later retry the job.

If a queueable callout throws an exception:

1. Error details are logged.
2. The job is marked failed.
3. The queue continues with the next job.

### Job Trigger Failure Handling

`AIServerJobTriggerHandler` classifies failures by message keywords.

Transient retry keywords include:

- `crew`
- `jwt`
- `session`
- `server error. status: internal server error, body: internal server error`
- `auth`
- `expir`

Operational alert keywords include:

- Down/network: `Read timed out`, `timeout`, `timed out`, `connection refused`, `host unreachable`
- Quota: `Quota exceeded`, `Rate limit`, `429`, `Resource exhausted`

## Data Transfer Summary

Salesforce sends:

- Source record ID.
- Flow-specific endpoint path.
- HTTP request through Named Credential `AI_Server`.

The AI Server writes back to Salesforce:

- `AI_Server_Job__c.Status__c`
- `AI_Server_Job__c.Message__c`
- `AI_Server_Job__c.Progress_Details__c`
- `AI_Server_Job__c.Logs__c`
- `Application_Verification_Summary__c` for admissions
- `EEDL_Verification_Summary__c` for EEDL
- Opportunity citizenship field for EEDL identity extraction, when the AI Server returns a clean pass and normalizes the value to the CRM picklist contract

## Operational Checklist

Before enabling EEDL automation in an org:

1. Confirm Named Credential `AI_Server` points to the correct environment.
2. Confirm `AI_Server_ChokePoint__mdt.EEDL_Automated_Verification` is enabled.
3. Confirm `AI_Server_Job__c.Opportunity__c` exists and is visible to operators.
4. Confirm `EEDL_Verification_Summary__c` and its fields are deployed.
5. Confirm Opportunity record type developer names match the allowlist.
6. Confirm job status values used by Apex match the deployed picklist values.
7. Confirm files are uploaded where the external AI Server expects to find them.
8. Confirm the admin permission set grants access to EEDL classes, tabs, and fields.
