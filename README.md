# isb-ai-server-salesforce

Salesforce metadata and Apex package for the ISB AI Document Verification Server integration.

This repository contains all Salesforce-side configurations for the AI-powered document verification platform, supporting both **Admission Application** and **EEDL/Opportunity** based verification workflows.

## Project Structure

```
isb-ai-server-salesforce/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/          # Apex classes and test classes
│           ├── triggers/         # Apex triggers
│           ├── objects/          # Custom objects and fields
│           ├── lwc/              # Lightning Web Components
│           ├── flexipages/       # Lightning App Builder pages
│           ├── permissionsets/   # Permission sets
│           ├── customMetadata/   # Custom Metadata Type records
│           ├── applications/     # Salesforce App definitions
│           └── tabs/             # Custom tabs
├── manifest/
│   └── package.xml               # Deployment manifest
├── docs/
│   └── UAT_EEDL_CHANGE_PACKAGE_2026-05-18.md
├── scripts/
│   └── python/
│       └── extract_coverage_lines.py
├── sfdx-project.json
└── README.md
```

## Key Components

### Apex Classes
- **`DocumentVerificationService`** — Central REST router dispatching verification requests
- **`EEDLVerificationGateway`** / **`ApplicationVerificationGateway`** — Gateway layer for EEDL and Application flows
- **`EducationVerificationHandler`** / **`TestScoreVerificationHandler`** / **`EmploymentVerificationHandler`** — Per-document-type handlers
- **`CEE_OpportunityTriggerHandler`** — EEDL Opportunity lifecycle management
- **`AVSTriggerHandler`** — Application Verification Summary trigger handler

### Lightning Web Components
- **`aiServerAdminView`** — Admin operator UI for monitoring AI verification jobs
- **`eedlManualVerificationAction`** — Manual verification action for EEDL records

### Custom Metadata
- **`AI_Server_ChokePoint__mdt`** — Feature flags (enable/disable AI verification per object type)

## Target Environment

- Salesforce Org: `ISB-UAT-New` (`nitesh.sinwar@myridius.com.partialcopy`)
- Source API Version: `64.0`

## Deployment Commands

### Validate (Dry-Run)
```bash
sf project deploy start \
  --dry-run \
  --source-dir force-app \
  --target-org ISB-UAT-New \
  --test-level RunSpecifiedTests \
  --tests AVSTriggerHandlerTest,CEE_OpportunityTriggerHandlerTest,EducationVerificationHandlerTest,TestScoreVerificationHandlerTest
```

### Deploy
```bash
sf project deploy start \
  --source-dir force-app \
  --target-org ISB-UAT-New \
  --test-level RunSpecifiedTests \
  --tests AVSTriggerHandlerTest,CEE_OpportunityTriggerHandlerTest,EducationVerificationHandlerTest,TestScoreVerificationHandlerTest
```

### Run Tests Only
```bash
sf apex run test \
  -n AVSTriggerHandlerTest,CEE_OpportunityTriggerHandlerTest,EducationVerificationHandlerTest,TestScoreVerificationHandlerTest \
  -c -r human -w 10 \
  -o ISB-UAT-New
```

## Validation History

| Date | Deploy ID | Notes |
|------|-----------|-------|
| 2026-05-18 | `0Affs000000kvg1CAA` | Initial EEDL UAT deploy |
| 2026-06-10 | `0Affs000000oL2rCAE` | Restructured to SFDX format; 46/46 tests passing |
