# UAT Change Package — EEDL AI Verification Integration

**Date:** 2026-05-18  
**Target org:** `ISB-UAT`  
**Intent:** Production-style UAT rehearsal for adding EEDL as a second workflow on top of the existing admissions AI-verification platform.

## Architecture boundary

- **Shared platform reused by both flows**
  - `AI_Server_Job__c`
  - `VerificationScheduler`
  - `AIServerJobTriggerHandler`
  - `AIserverAdminViewController`
  - Named Credential `AI_Server`
- **Admissions-only artifacts intentionally left admissions-only**
  - `Application_Verification_Summary__c`
  - `AVSTrigger*`
  - `DocumentChecklistItem.Application_Verification_Summary__c`
  - `Detail_Verification_Issue__mdt`
  - `Document_Verification_Issue__mdt`
  - admissions-specific choke-point records
- **EEDL-specific vertical introduced beside admissions**
  - Opportunity-based queueing
  - EEDL summary persistence
  - EEDL callout route
  - EEDL operator UX

## Created in this package

### Apex

- `EEDLVerificationGateway`
- `EEDLVerificationGatewayTest`
- `EEDLVerificationCalloutService`
- `EEDLVerificationCalloutServiceTest`

### Metadata / data model

- `AI_Server_Job__c.Opportunity__c`
- `EEDL_Verification_Summary__c`
- `EEDL_Verification_Summary__c.Confidence_Score__c`
- `EEDL_Verification_Summary__c.Doc_Last_Modified__c`
- `EEDL_Verification_Summary__c.Education_Record_Id__c`
- `EEDL_Verification_Summary__c.Education__c`
- `EEDL_Verification_Summary__c.Last_Processed_At__c`
- `EEDL_Verification_Summary__c.Mismatched_Field_List__c`
- `EEDL_Verification_Summary__c.Opportunity__c`
- `EEDL_Verification_Summary__c.Overall_Feedback__c`
- `EEDL_Verification_Summary__c.Overall_Status__c`
- `EEDL_Verification_Summary__c.Record_Last_Modified__c`
- `EEDL_Verification_Summary__c.Record_Type__c`
- `EEDL_Verification_Summary__c.Summary_HTML__c`
- `AI_Server_ChokePoint__mdt.EEDL_Automated_Verification`

### Operator UX

- `eedlManualVerificationButton` LWC
- `EEDL_Verification_Summary_Record_Page` flexipage
- `EEDL_Verification_Summary__c` custom tab

## Modified in this package

### Shared orchestration / resilience

- `VerificationScheduler`
  - Dispatches both admissions and EEDL queued jobs from the same shared capacity pool.
- `VerificationSchedulerTest`
  - Covers dual-flow scheduling behavior.
- `AIServerJobTriggerHandler`
  - Keeps admissions-only checklist updates isolated.
  - Makes operational alerts safe for both `Application__c` and `Opportunity__c` jobs.
  - Keeps test-time checklist processing coverable without changing production choke-point behavior.
- `AIServerJobTriggerHandlerTest`
  - Adds EEDL-safe alert-path coverage.
- `AIserverAdminViewController`
  - Makes active jobs, concluded jobs, API transactions, logs, retry, and delete flows dual-flow aware.
- `AIserverAdminViewControllerTest`
  - Adds EEDL visibility, logs, retry, and server-payload coverage.

### EEDL trigger / eligibility

- `CEE_OpportunityTrigger`
  - Invokes EEDL verification on eligible Opportunity stage transitions.
- `CEE_OpportunityTriggerHandler`
  - Adds EEDL automation entry point.
  - Opens EEDL automation to the relevant CEE / Executive Education opportunity family:
    - `CEE_Custom`
    - `CEE_HR`
    - `CEE_Open_LDP`
    - `CEE_Open_SDP`
    - `EE_Govt`
    - `ExecEd_B2B`
    - `ExecEdDefault`
    - `Online_Program`

### Permissions and operator navigation

- `AI_Server_Admin_Panel` permission set
  - Adds EEDL class access.
  - Adds CRUD/FLS for `AI_Server_Job__c.Opportunity__c` and `EEDL_Verification_Summary__c`.
  - Adds visibility for the EEDL summary tab.
- `aiServerAdminView` LWC
  - Adds dual-flow source labeling and Opportunity links.
- `Exec_Education_and_DL_Opportunity_Record_page`
  - Adds manual EEDL verification button placement.
  - Adds an explicit EEDL verification summary related-list card.
- `EEDL_New` app
  - Adds the EEDL summary tab.

### Admissions regression harness repair

- `ApplicationVerificationGatewayTest`
  - Reorders recommender setup so response creation occurs before the submitted-state lock.
  - Replaces brittle “org starts empty” assertions with “no additional side effect” assertions.
  - Uses fresh recommender scenario records instead of mutating already-locked submitted records.
  - Aligns the duplicate-email test with current UAT validation, which now blocks applicant/recommender email matches before the gateway can process them.

## Intentionally not modified

- Admissions summary object and admissions issue metadata remain admissions-only.
- Admissions document-checklist automation remains admissions-only.
- Named Credential routing remains environment-specific and code-agnostic:
  - Apex keeps using `callout:AI_Server/api/v1/...`
  - each org controls `/dev/`, `/uat/`, or `/prod/` via its own Named Credential endpoint.

## Validation / deployment record

| Item | Result |
|---|---|
| Final deployment validation | **Succeeded** — `0Affs000000ktG3CAI` |
| Final UAT deployment | **Succeeded** — quick deploy `0Affs000000kvg1CAA` |
| Components deployed | **35 / 35** |
| Targeted tests validated | **124 / 124 passed** |
| Targeted admissions tests | **Passed** |
| Targeted EEDL tests | **Passed** |
| Shared retry/admin tests | **Passed** |

## UAT deployment notes

- Final validation completed on **2026-05-18 13:13:08 UTC**.
- Final UAT quick deploy completed on **2026-05-18 13:14:20 UTC** using the successful validation above.
- A prior validation exposed stale admissions-test assumptions; those were repaired before the final successful validation.
- No legacy Opportunity page-layout metadata was deployed. UAT currently contains unrelated stale CTI related-list references in those layouts, so the EEDL operator surface was delivered through Lightning pages instead:
  - manual verification button on `Exec_Education_and_DL_Opportunity_Record_page`
  - explicit EEDL summary related-list card on that Lightning page
  - dedicated `EEDL_Verification_Summary_Record_Page`
  - dedicated `EEDL_Verification_Summary__c` tab

## Actual final UAT delta

### Created in the final UAT deploy

- `eedlManualVerificationButton`
- `EEDL_Verification_Summary_Record_Page`
- `EEDL_Verification_Summary__c` custom tab

### Changed in the final UAT deploy

- `AIServerJobTriggerHandler`
- `AIServerJobTriggerHandlerTest`
- `AIserverAdminViewController`
- `AIserverAdminViewControllerTest`
- `ApplicationVerificationGatewayTest`
- `CEE_OpportunityTriggerHandler`
- `CEE_OpportunityTrigger`
- `aiServerAdminView`
- `EEDL_Verification_Summary__c` object metadata
- `Exec_Education_and_DL_Opportunity_Record_page`
- `EEDL_New`
- `AI_Server_Admin_Panel`

### Included for complete-package validation but already present in UAT

- `EEDLVerificationGateway`
- `EEDLVerificationGatewayTest`
- `EEDLVerificationCalloutService`
- `EEDLVerificationCalloutServiceTest`
- `VerificationScheduler`
- `VerificationSchedulerTest`
- `AI_Server_Job__c.Opportunity__c`
- `EEDL_Verification_Summary__c` field set
- `AI_Server_ChokePoint__mdt.EEDL_Automated_Verification`

## Targeted test scope

- `ApplicationVerificationGatewayTest`
- `AppVerifCalloutSvcTest`
- `VerificationSchedulerTest`
- `EEDLVerificationGatewayTest`
- `EEDLVerificationCalloutServiceTest`
- `AIServerJobTriggerHandlerTest`
- `AIserverAdminViewControllerTest`
- `CEE_OpportunityTriggerHandlerTest`
