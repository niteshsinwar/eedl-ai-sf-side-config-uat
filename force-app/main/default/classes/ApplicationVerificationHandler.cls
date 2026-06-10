/**
 * @description Enhanced Application document verification handler with graceful fallback support.
 * Maintains original class name and method signatures while adding internal fallback logic.
 * When documents or critical data are missing, returns structured error messages instead of throwing exceptions.
 * This prevents job failures and provides clear feedback about data issues.
 *
 * @author Nitish Sinwar
 * @version Enhanced with Fallback Support (maintains original API)
 */
public with sharing class ApplicationVerificationHandler {
    private static final String HANDLER_SERVICE_NAME = 'APPLICATION_HANDLER'; // Convention: SCREAMING_SNAKE_CASE
    // Constants specific to Application and related Contact
    public static final String SOBJECT_API_NAME = 'hed__Application__c';
    public static final String SOBJECT_API_NAME_FOR_ERROR = 'Application';
    private static final String CONTACT_SOBJECT_API_NAME = 'Contact';
    private static final String CONTACT_SOBJECT_API_NAME_FOR_ERROR = 'Contact (Applicant)';

    // New constant for fallback handling
    private static final String FALLBACK_SUMMARY_KEY = 'Salesforce_data_issue_Summary';

    /**
     * @description Enhanced version of the original method that provides graceful fallback.
     * Maintains the same method name and signature but now handles errors gracefully.
     * Instead of throwing exceptions, returns structured data with error summary when issues occur.
     * @param applicationId The ID of the hed__Application__c record.
     * @return A DocumentVerificationUtils.VerificationDataWrapper containing the record data and document payload or fallback error.
     */
    public static DocumentVerificationUtils.VerificationDataWrapper getApplicationVerificationDataPackage(Id applicationId) {
        DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Preparing Application data for ID: ' + applicationId);

        try {
            // Input validation with graceful fallback
            if (applicationId == null) {
                return createFallbackResponse(
                    createBasicPayload(null, 'ApplicationDetails'),
                    'Application ID is required for verification.'
                );
            }

            // Fetch application record with error handling
            hed__Application__c applicationRecord = fetchApplicationRecord(applicationId);
            if (applicationRecord == null) {
                return createFallbackResponse(
                    createBasicPayload(applicationId, 'ApplicationDetails'),
                    'Application record not found in Salesforce. Please verify the Application ID exists and is accessible.'
                );
            }

            // Check for linked applicant
            if (applicationRecord.hed__Applicant__c == null) {
                return createFallbackResponse(
                    createBasicPayload(applicationId, 'ApplicationDetails'),
                    'No Applicant (Contact) is linked to this Application record. Please ensure the Applicant field is populated.'
                );
            }

            // Fetch related Task and DocumentChecklistItem IDs
            List<Task> tasks = [
                SELECT Id FROM Task
                WHERE Subject LIKE '%Personal Details%' AND WhatId = :applicationId LIMIT 1
            ];
            Id taskId = tasks.isEmpty() ? null : tasks[0].Id;

            List<DocumentChecklistItem> dclItems = [
                SELECT Id FROM DocumentChecklistItem
                WHERE Name LIKE '%proof of Identity%' AND ParentRecordId = :applicationId LIMIT 1
            ];
            Id dclId = dclItems.isEmpty() ? null : dclItems[0].Id;

            // Fetch contact record with error handling
            Contact applicantContact = fetchContactDetailsRecord(applicationRecord.hed__Applicant__c);
            if (applicantContact == null) {
                return createFallbackResponse(
                    createBasicPayload(applicationId, 'ApplicationDetails'),
                    'Applicant Contact record not found or inaccessible. Contact ID: ' + applicationRecord.hed__Applicant__c
                );
            }

            // Attempt to fetch document with graceful fallback
            ContentVersion documentVersion = null;
            String documentError = null;

            try {
                documentVersion = DocumentVerificationUtils.fetchLatestDocumentVersion(
                    applicantContact.Id,
                    'Applicant ID Proof Document'
                );

                if (documentVersion == null) {
                    documentError = 'No ID proof document attached to the Applicant Contact record. Please upload the required identity document.';
                } else {
                    DocumentVerificationUtils.validateDocument(documentVersion);
                }
            } catch (Exception docException) {
                documentError = 'Document retrieval failed: ' + docException.getMessage() + '. Please check the document attachment and try again.';
            }

            // If document issues, return fallback response with complete payload
            if (documentError != null) {
                Map<String, Object> fallbackPayload = prepareApplicationPayload(applicationRecord, applicantContact, taskId, dclId);
                return createFallbackResponse(fallbackPayload, documentError);
            }

            // Success path - return complete data package
            String base64Data = EncodingUtil.base64Encode(documentVersion.VersionData);
            DocumentVerificationUtils.DocumentPayload documentPayload = new DocumentVerificationUtils.DocumentPayload(
                documentVersion.Title, documentVersion.FileExtension, base64Data, documentVersion.ContentSize, documentVersion.LastModifiedDate
            );

            Map<String, Object> recordMap = prepareApplicationPayload(applicationRecord, applicantContact, taskId, dclId);

            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Successfully prepared complete data package for Application: ' + applicationId);
            return new DocumentVerificationUtils.VerificationDataWrapper(recordMap, documentPayload);

        } catch (Exception e) {
            // Catch-all fallback for unexpected errors
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Unexpected error in Application verification: ' + e.getMessage());
            return createFallbackResponse(
                createBasicPayload(applicationId, 'ApplicationDetails'),
                'Unexpected error during Application verification: ' + e.getMessage() + '. Please contact system administrator.'
            );
        }
    }

    /**
     * @description Enhanced fetchApplicationRecord method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     * @param applicationId The ID of the Application record.
     * @return The hed__Application__c SObject or null if not found.
     */
    private static hed__Application__c fetchApplicationRecord(Id applicationId) {
        try {
            List<hed__Application__c> applicationRecords = [
                SELECT Id, Name, hed__Applicant__c
                FROM hed__Application__c
                WHERE Id = :applicationId LIMIT 1
            ];
            return applicationRecords.isEmpty() ? null : applicationRecords[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Application record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced fetchContactDetailsRecord method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     * @param contactId The ID of the Contact record.
     * @return The Contact SObject or null if not found.
     */
    private static Contact fetchContactDetailsRecord(Id contactId) {
        try {
            List<Contact> contactRecords = [
                SELECT Id, Name, Passport_Number__c, Birthdate, hed__Gender__c,
                       PassportExpiryDate__c, hed__Citizenship__c, Aadhar_Card_Number__c, LastModifiedDate
                FROM Contact
                WHERE Id = :contactId LIMIT 1
            ];
            return contactRecords.isEmpty() ? null : contactRecords[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Contact record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced prepareApplicationPayload method with additional error summary handling.
     * Maintains original method name and signature.
     * @param application The hed__Application__c SObject.
     * @param applicantContact The related Contact SObject (Applicant).
     * @param taskId The ID of the related Task record.
     * @param dclId The ID of the related DocumentChecklistItem record.
     * @return A Map<String, Object> containing key-value pairs of the application and applicant data.
     */
    private static Map<String, Object> prepareApplicationPayload(
        hed__Application__c application, Contact applicantContact, Id taskId, Id dclId
    ) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('recordId', application.Id);
        payload.put('type', 'ApplicationDetails');

        // Add Task and DocumentChecklistItem IDs to payload
        payload.put('Task_Id', taskId);
        payload.put('DocumentchecklistItem_Id', dclId);

        // Contact information with null-safe handling
        payload.put('Full Name', applicantContact.Name != null ? applicantContact.Name : 'Name not available');
        payload.put('Birthdate', applicantContact.Birthdate != null ? DocumentVerificationUtils.formatDate(applicantContact.Birthdate) : null);
        payload.put('Gender', applicantContact.get('hed__Gender__c'));
        payload.put('Nationality', applicantContact.hed__Citizenship__c != null ? applicantContact.hed__Citizenship__c : null);

        String passportNumber = (String)applicantContact.get('Passport_Number__c');
        String aadharNumber = String.valueOf(applicantContact.get('Aadhar_Card_Number__c'));

        if ('null'.equalsIgnoreCase(aadharNumber) || String.isBlank(aadharNumber)) {
             aadharNumber = null;
        }

        String idProofType = 'None';
        if (!String.isBlank(aadharNumber) && String.isBlank(passportNumber)) {
            idProofType = 'Aadhar';
        } else if (!String.isBlank(passportNumber) && String.isBlank(aadharNumber)) {
            idProofType = 'Passport';
        } else if (!String.isBlank(passportNumber) && !String.isBlank(aadharNumber)) {
            idProofType = 'Decide from Related Document';
        }
        payload.put('ID Proof Type', idProofType);
        payload.put('Passport Number', passportNumber);
        payload.put('PassportExpiryDate', applicantContact.get('PassportExpiryDate__c') != null ? DocumentVerificationUtils.formatDate((Date)applicantContact.get('PassportExpiryDate__c')) : null);
        payload.put('Aadhar Card Number', aadharNumber);
        payload.put('Applicant__c', application.hed__Applicant__c);
        payload.put('LastModifiedDate', applicantContact.LastModifiedDate);

        return payload;
    }

    // ==================== NEW HELPER METHODS FOR FALLBACK SUPPORT ====================

    /**
     * @description Creates a fallback response when normal processing cannot continue.
     * This method is called internally to provide graceful error handling.
     * @param recordData The partial record data if available
     * @param errorSummary Human-readable error message
     * @return VerificationDataWrapper with error summary and no document payload
     */
    private static DocumentVerificationUtils.VerificationDataWrapper createFallbackResponse(
        Map<String, Object> recordData,
        String errorSummary
    ) {
        if (recordData == null) {
            recordData = new Map<String, Object>();
        }

        // Add the error summary that Python microservice expects
        recordData.put(FALLBACK_SUMMARY_KEY, errorSummary);

        DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Returning fallback response: ' + errorSummary);

        // Return wrapper with record data containing error summary, but no document payload
        return new DocumentVerificationUtils.VerificationDataWrapper(recordData, null);
    }

    /**
     * @description Creates a basic payload structure with minimal required fields.
     * Used when complete data is not available but we need to return a structured response.
     * @param recordId The record ID
     * @param recordType The type of record
     * @return Basic payload map with expected structure
     */
    private static Map<String, Object> createBasicPayload(Id recordId, String recordType) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('recordId', recordId);
        payload.put('type', recordType);

        // Add placeholder values that match expected structure from Python microservice
        payload.put('Full Name', 'Data not available');
        payload.put('Birthdate', null);
        payload.put('Gender', null);
        payload.put('Nationality', null);
        payload.put('ID Proof Type', 'Unknown');
        payload.put('Passport Number', null);
        payload.put('PassportExpiryDate', null);
        payload.put('Aadhar Card Number', null);
        payload.put('Task_Id', null);
        payload.put('DocumentchecklistItem_Id', null);
        payload.put('Applicant__c', null);
        payload.put('LastModifiedDate', null);

        return payload;
    }
}