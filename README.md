# EEDL AI Salesforce Side Config UAT

Salesforce UAT deployment package for the EEDL AI-based verification flow.

This package contains Salesforce metadata and Apex components for extending the existing AI verification platform with an EEDL Opportunity-based workflow, including queue orchestration, callout integration, summary persistence, operator UI, permissions, tabs, and Lightning page updates.

## Contents

- Apex classes, tests, and triggers for EEDL verification and shared orchestration.
- Lightning Web Components for the AI server admin view and manual EEDL verification action.
- Custom object, field, custom metadata, permission set, tab, app, and Flexipage metadata.
- `package.xml` for deployment.
- `UAT_EEDL_CHANGE_PACKAGE_2026-05-18.md` with deployment notes and validation history.

## Target Environment

- Salesforce org: `ISB-UAT`
- Package date: `2026-05-18`
- Validation record: `0Affs000000ktG3CAI`
- Quick deploy record: `0Affs000000kvg1CAA`
