/**
 * @description Enhanced Employment document verification handler with graceful fallback support.
 * Maintains original class name and method signatures while adding internal fallback logic.
 * It uses ISB_Employment_Log__c as the entry point, fetches related hed__Affiliation__c
 * for employment details, and finds the document via DocumentChecklistItem linked to the Application.
 * When documents or critical data are missing, returns structured error messages instead of throwing exceptions.
 * @author Nitish Sinwar
 * @version Enhanced with Fallback Support (maintains original API)
 */
public with sharing class EmploymentVerificationHandler {

    private static final String HANDLER_SERVICE_NAME = 'EMPLOYMENT_HANDLER';

    // Constants for ISB_Employment_Log__c (the entry point SObject)
    public static final String LOG_OBJECT_API_NAME = 'ISB_Employment_Log__c';
    public static final String SOBJECT_API_NAME_FOR_ERROR = 'ISB Employment Log';
    private static final String LOG_APPLICATION_LOOKUP_FIELD = 'Application__c'; // Field on Log to Application
    private static final String LOG_TO_DETAIL_LOOKUP_FIELD = 'Affiliation__c';   // Field on Log to hed__Affiliation__c

    // Constants for hed__Application__c (used to get Applicant and DocumentChecklistItem)
    private static final String APPLICATION_OBJECT_API_NAME = 'hed__Application__c';
    private static final String APPLICATION_APPLICANT_NAME_FIELD = 'Applicant__c';

    // Constants for hed__Affiliation__c (the detail SObject whose data is returned)
    public static final String DETAIL_OBJECT_API_NAME = 'hed__Affiliation__c';
    public static final String DETAIL_SOBJECT_FOR_ERROR = 'Affiliation Detail';
    private static final String AFFILIATION_START_DATE_FIELD = 'Start_Date_Formula__c';
    private static final String AFFILIATION_END_DATE_FIELD = 'End_Date_Formula__c';
    private static final String AFFILIATION_COMPANY_FIELD = 'Company_Name__c';
    private static final String AFFILIATION_DESIGNATION_FIELD = 'Employment_Designation__c';
    private static final String AFFILIATION_COMPENSATION_FIELD = 'Compensation_End_Amount__c';
    private static final String AFFILIATION_CURRENCY_FIELD =  'Compensation_End_Currency__c';

    // Constants for DocumentChecklistItem
    private static final String DCI_OBJECT_API_NAME = 'DocumentChecklistItem';
    private static final String DCI_PARENT_RECORD_ID_FIELD = 'ParentRecordId';

    // New constant for fallback handling
    private static final String FALLBACK_SUMMARY_KEY = 'Salesforce_data_issue_Summary';

    /**
     * @description Enhanced method that provides graceful fallback for employment verification.
     * Maintains the same method name and signature but now handles errors gracefully.
     * Instead of throwing exceptions, returns structured data with error summary when issues occur.
     * @param employmentLogId The ID of the ISB_Employment_Log__c record.
     * @return A DocumentVerificationUtils.VerificationDataWrapper containing the record data and document payload or fallback error.
     */
    public static DocumentVerificationUtils.VerificationDataWrapper getEmploymentVerificationDataPackage(Id employmentLogId) {
        DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Preparing Employment data for ' + LOG_OBJECT_API_NAME + ' ID: ' + employmentLogId);

        try {
            // Input validation with graceful fallback
            if (employmentLogId == null) {
                return createFallbackResponse(
                    createBasicPayload(null, 'EmploymentDetails'),
                    'Employment Log ID is required for verification.'
                );
            }

            // 1. Fetch the ISB_Employment_Log__c record with error handling
            ISB_Employment_Log__c employmentLog = fetchEmploymentLog(employmentLogId);
            if (employmentLog == null) {
                return createFallbackResponse(
                    createBasicPayload(employmentLogId, 'EmploymentDetails'),
                    'Employment Log record not found in Salesforce. Please verify the Employment Log ID exists and is accessible.'
                );
            }

            Id applicationId = (Id)employmentLog.get(LOG_APPLICATION_LOOKUP_FIELD);
            Id actualAffiliationId = (Id)employmentLog.get(LOG_TO_DETAIL_LOOKUP_FIELD);

            if (applicationId == null) {
                return createFallbackResponse(
                    createBasicPayload(employmentLogId, 'EmploymentDetails'),
                    'Application lookup is missing on Employment Log record. Please ensure the Application field is populated.'
                );
            }

            if (actualAffiliationId == null) {
                return createFallbackResponse(
                    createBasicPayload(employmentLogId, 'EmploymentDetails'),
                    'Affiliation lookup is missing on Employment Log record. Please ensure the Affiliation field is populated.'
                );
            }

            // 2. Fetch related Task ID
            List<Task> tasks = [
                SELECT Id FROM Task
                WHERE WhatId = :applicationId AND Subject LIKE '%Employment Details%'
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            Id taskId = tasks.isEmpty() ? null : tasks[0].Id;

            // 3. Fetch applicant name and affiliation details with error handling
            String applicantName = fetchApplicantName(applicationId);
            SObject affiliationRecord = fetchAffiliationDetails(actualAffiliationId);
            if (affiliationRecord == null) {
                return createFallbackResponse(
                    createBasicPayload(employmentLogId, 'EmploymentDetails'),
                    'Affiliation detail record not found. Record ID: ' + actualAffiliationId
                );
            }

            // 4. Find document via DocumentChecklistItem with graceful fallback
            Id documentChecklistItemId = findProofOfIncomeDCI(applicationId);
            if (documentChecklistItemId == null) {
                Map<String, Object> partialPayload = prepareEmploymentPayload(affiliationRecord, employmentLogId, applicantName, taskId, null);
                return createFallbackResponse(
                    partialPayload,
                    'Required employment document not found. Expected document type: "Proof of income for self" for Application ID: ' + applicationId
                );
            }

            // 5. Attempt to fetch document with graceful fallback
            ContentVersion documentVersion = null;
            String documentError = null;

            try {
                documentVersion = DocumentVerificationUtils.fetchLatestDocumentVersion(
                    documentChecklistItemId,
                    'Proof of Income Document'
                );

                if (documentVersion == null) {
                    documentError = 'No employment income document attached to the DocumentChecklistItem. Please upload the required proof of income document.';
                } else {
                    DocumentVerificationUtils.validateDocument(documentVersion);
                }
            } catch (Exception docException) {
                documentError = 'Document retrieval failed for employment verification: ' + docException.getMessage() + '. Please check the document attachment and try again.';
            }

            // If document issues, return fallback response with complete payload
            if (documentError != null) {
                Map<String, Object> fallbackPayload = prepareEmploymentPayload(affiliationRecord, employmentLogId, applicantName, taskId, documentChecklistItemId);
                return createFallbackResponse(fallbackPayload, documentError);
            }

            // Success path - return complete data package
            String base64Data = EncodingUtil.base64Encode(documentVersion.VersionData);
            DocumentVerificationUtils.DocumentPayload documentPayload = new DocumentVerificationUtils.DocumentPayload(
                documentVersion.Title, documentVersion.FileExtension, base64Data, documentVersion.ContentSize, documentVersion.LastModifiedDate
            );

            Map<String, Object> recordMap = prepareEmploymentPayload(affiliationRecord, employmentLogId, applicantName, taskId, documentChecklistItemId);

            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Successfully prepared complete data package for Employment Log: ' + employmentLogId);
            return new DocumentVerificationUtils.VerificationDataWrapper(recordMap, documentPayload);

        } catch (Exception e) {
            // Catch-all fallback for unexpected errors
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Unexpected error in Employment verification: ' + e.getMessage());
            return createFallbackResponse(
                createBasicPayload(employmentLogId, 'EmploymentDetails'),
                'Unexpected error during Employment verification: ' + e.getMessage() + '. Please contact system administrator.'
            );
        }
    }

    /**
     * @description Enhanced fetchEmploymentLog method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     */
    private static ISB_Employment_Log__c fetchEmploymentLog(Id employmentLogId) {
        try {
            String soqlQuery = 'SELECT Id, ' + LOG_APPLICATION_LOOKUP_FIELD + ', ' + LOG_TO_DETAIL_LOOKUP_FIELD +
                               ' FROM ' + LOG_OBJECT_API_NAME +
                               ' WHERE Id = :employmentLogId LIMIT 1';
            List<ISB_Employment_Log__c> employmentLogs = Database.query(soqlQuery);
            return employmentLogs.isEmpty() ? null : employmentLogs[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Employment Log record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced fetchApplicantName method with graceful error handling.
     * Maintains original method name and improved error handling.
     */
    private static String fetchApplicantName(Id applicationId) {
        try {
            String soqlQuery = 'SELECT ' + APPLICATION_APPLICANT_NAME_FIELD +
                           ' FROM ' + APPLICATION_OBJECT_API_NAME +
                           ' WHERE Id = :applicationId LIMIT 1';
            List<SObject> applicationRecords = Database.query(soqlQuery);
            if (!applicationRecords.isEmpty() && applicationRecords[0] != null) {
                return (String)applicationRecords[0].get(APPLICATION_APPLICANT_NAME_FIELD);
            }
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Applicant Name for Application ID ' + applicationId + ': ' + e.getMessage());
        }
        return 'Applicant name not available';
    }

    /**
     * @description Enhanced fetchAffiliationDetails method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     */
    private static SObject fetchAffiliationDetails(Id affiliationId) {
        try {
            String fieldsToQuery = 'Id, Name, LastModifiedDate, ' +
                                   AFFILIATION_START_DATE_FIELD + ', ' +
                                   AFFILIATION_END_DATE_FIELD + ', ' +
                                   AFFILIATION_COMPANY_FIELD + ', ' +
                                   AFFILIATION_DESIGNATION_FIELD + ', ' +
                                   AFFILIATION_CURRENCY_FIELD + ', ' +
                                   AFFILIATION_COMPENSATION_FIELD;

            String soqlQuery = 'SELECT ' + fieldsToQuery +
                           ' FROM ' + DETAIL_OBJECT_API_NAME +
                           ' WHERE Id = :affiliationId LIMIT 1';
            List<SObject> affiliationRecords = Database.query(soqlQuery);
            return affiliationRecords.isEmpty() ? null : affiliationRecords[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Affiliation record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced findProofOfIncomeDCI method with better error handling.
     * Maintains original method logic with improved error handling.
     */
    private static Id findProofOfIncomeDCI(Id applicationId) {
        try {
            String dciNameCriteria = 'Proof of income for self';
            String searchPattern = '%' + dciNameCriteria + '%';
            String dciQueryString = 'SELECT Id FROM ' + DCI_OBJECT_API_NAME +
                                  ' WHERE ' + DCI_PARENT_RECORD_ID_FIELD + ' = :applicationId ' +
                                  ' AND Name LIKE :searchPattern ' +
                                  ' ORDER BY CreatedDate DESC LIMIT 1';
            List<SObject> dciItems = Database.query(dciQueryString);
            return dciItems.isEmpty() ? null : dciItems[0].Id;
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error querying DocumentChecklistItem: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced prepareEmploymentPayload method.
     * Maintains original method name and signature with null-safe handling.
     */
    private static Map<String, Object> prepareEmploymentPayload(SObject affiliation, Id employmentLogId, String applicantName, Id taskId, Id dclId) {
        Map<String, Object> payload = new Map<String, Object>();

        payload.put('Id', affiliation.Id);
        payload.put('triggeringLogId', employmentLogId);

        // Add Task and DocumentChecklistItem IDs to payload
        payload.put('Task_Id', taskId);
        payload.put('DocumentchecklistItem_Id', dclId);

        payload.put('type', 'EmploymentDetails');
        payload.put('applicantName', applicantName != null ? applicantName : 'Applicant name not available');
        payload.put('employerName', affiliation.get(AFFILIATION_COMPANY_FIELD));
        payload.put('jobTitle', affiliation.get(AFFILIATION_DESIGNATION_FIELD));
        payload.put('startDate', affiliation.get(AFFILIATION_START_DATE_FIELD));
        payload.put('endDate', affiliation.get(AFFILIATION_END_DATE_FIELD));
        payload.put('compensation', affiliation.get(AFFILIATION_COMPENSATION_FIELD));
        payload.put('currency', affiliation.get(AFFILIATION_CURRENCY_FIELD));
        payload.put('LastModifiedDate', affiliation.get('LastModifiedDate'));

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
        payload.put('Id', null);
        payload.put('triggeringLogId', recordId);
        payload.put('type', recordType);

        // Add placeholder values that match expected structure from Python microservice
        payload.put('Task_Id', null);
        payload.put('DocumentchecklistItem_Id', null);
        payload.put('applicantName', 'Data not available');
        payload.put('employerName', null);
        payload.put('jobTitle', null);
        payload.put('startDate', null);
        payload.put('endDate', null);
        payload.put('compensation', null);
        payload.put('currency', null);
        payload.put('LastModifiedDate', null);

        return payload;
    }
}