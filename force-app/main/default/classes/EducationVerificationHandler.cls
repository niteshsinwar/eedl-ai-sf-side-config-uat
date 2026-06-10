/**
 * @description Enhanced Education History document verification handler with graceful fallback support.
 * Maintains original class name and method signatures while adding internal fallback logic.
 * It now uses ISB_Education_Log__c as the entry point, fetches the related hed__Education_History__c
 * for details, and finds the document linked to the DocumentChecklistItem.
 * When documents or critical data are missing, returns structured error messages instead of throwing exceptions.
 * @author Nitish Sinwar
 * @version Enhanced with Fallback Support (maintains original API)
 */
public with sharing class EducationVerificationHandler {

    private static final String HANDLER_SERVICE_NAME = 'EDUCATION_HANDLER';

    // Constants for ISB_Education_Log__c (the entry point SObject)
    public static final String LOG_OBJECT_API_NAME = 'ISB_Education_Log__c';
    public static final String SOBJECT_API_NAME_FOR_ERROR = 'ISB Education Log';
    private static final String LOG_APPLICATION_LOOKUP_FIELD = 'Application__c';
    private static final String LOG_TO_DETAIL_LOOKUP_FIELD = 'Education_History__c';

    // Constants for hed__Education_History__c (the detail SObject whose data is returned)
    public static final String DETAIL_OBJECT_API_NAME = 'hed__Education_History__c';
    public static final String DETAIL_SOBJECT_FOR_ERROR = 'Education History Detail';

    // Constants for DocumentChecklistItem
    private static final String DCI_OBJECT_API_NAME = 'DocumentChecklistItem';
    private static final String DCI_PARENT_RECORD_ID_FIELD = 'ParentRecordId';

    // New constant for fallback handling
    private static final String FALLBACK_SUMMARY_KEY = 'Salesforce_data_issue_Summary';

    /**
     * @description Enhanced method that provides graceful fallback for education verification.
     * Maintains the same method name and signature but now handles errors gracefully.
     * Instead of throwing exceptions, returns structured data with error summary when issues occur.
     * @param educationLogId The ID of the ISB_Education_Log__c record.
     * @return A DocumentVerificationUtils.VerificationDataWrapper containing the record data and document payload or fallback error.
     */
    public static DocumentVerificationUtils.VerificationDataWrapper getEducationVerificationDataPackage(Id educationLogId) {
        DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Preparing Education data via ' + LOG_OBJECT_API_NAME + ' ID: ' + educationLogId);

        try {
            // Input validation with graceful fallback
            if (educationLogId == null) {
                return createFallbackResponse(
                    createBasicPayload(null, 'EducationHistory'),
                    'Education Log ID is required for verification.'
                );
            }

            // 1. Fetch the ISB_Education_Log__c record with error handling
            ISB_Education_Log__c educationLog = fetchEducationLog(educationLogId);
            if (educationLog == null) {
                return createFallbackResponse(
                    createBasicPayload(educationLogId, 'EducationHistory'),
                    'Education Log record not found in Salesforce. Please verify the Education Log ID exists and is accessible.'
                );
            }

            Id actualEducationHistoryId = (Id)educationLog.get(LOG_TO_DETAIL_LOOKUP_FIELD);
            Id applicationId = (Id)educationLog.get(LOG_APPLICATION_LOOKUP_FIELD);

            if (applicationId == null) {
                return createFallbackResponse(
                    createBasicPayload(educationLogId, 'EducationHistory'),
                    'Application lookup is missing on Education Log record. Please ensure the Application field is populated.'
                );
            }

            if (actualEducationHistoryId == null) {
                return createFallbackResponse(
                    createBasicPayload(educationLogId, 'EducationHistory'),
                    'Education History lookup is missing on Education Log record. Please ensure the Education History field is populated.'
                );
            }

            // 2. Fetch the actual hed__Education_History__c record with error handling
            hed__Education_History__c educationHistoryRecord = fetchEducationHistoryDetailRecord(actualEducationHistoryId);
            if (educationHistoryRecord == null) {
                return createFallbackResponse(
                    createBasicPayload(educationLogId, 'EducationHistory'),
                    'Education History detail record not found. Record ID: ' + actualEducationHistoryId
                );
            }

            // 3. Fetch related Task ID using Application ID
            List<Task> tasks = [
                SELECT Id FROM Task
                WHERE WhatId = :applicationId AND Subject LIKE '%Education Details%'
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            Id taskId = tasks.isEmpty() ? null : tasks[0].Id;

            // 4. Dynamically find DocumentChecklistItem based on Degree Level
            String dciNameCriteria = getDciNameCriteriaForDegree(educationHistoryRecord.Degree_Level__c);
            if (String.isBlank(dciNameCriteria)) {
                Map<String, Object> partialPayload = prepareEducationHistoryPayload(educationHistoryRecord, educationLogId, taskId, null);
                return createFallbackResponse(
                    partialPayload,
                    'Unsupported Degree Level for document verification: ' + educationHistoryRecord.Degree_Level__c + '. Please contact system administrator.'
                );
            }

            Id documentChecklistItemId = findDocumentChecklistItemByName(applicationId, dciNameCriteria);
            if (documentChecklistItemId == null) {
                Map<String, Object> partialPayload = prepareEducationHistoryPayload(educationHistoryRecord, educationLogId, taskId, null);
                return createFallbackResponse(
                    partialPayload,
                    'Required education document not found. Expected document type: "' + dciNameCriteria + '" for Application ID: ' + applicationId
                );
            }

            // 5. Attempt to fetch document with graceful fallback
            ContentVersion documentVersion = null;
            String documentError = null;

            try {
                documentVersion = DocumentVerificationUtils.fetchLatestDocumentVersion(
                    documentChecklistItemId,
                    dciNameCriteria
                );

                if (documentVersion == null) {
                    documentError = 'No education document attached to the DocumentChecklistItem. Expected document type: ' + dciNameCriteria;
                } else {
                    DocumentVerificationUtils.validateDocument(documentVersion);
                }
            } catch (Exception docException) {
                documentError = 'Document retrieval failed for education verification: ' + docException.getMessage() + '. Please check the document attachment and try again.';
            }

            // If document issues, return fallback response with complete payload
            if (documentError != null) {
                Map<String, Object> fallbackPayload = prepareEducationHistoryPayload(educationHistoryRecord, educationLogId, taskId, documentChecklistItemId);
                return createFallbackResponse(fallbackPayload, documentError);
            }

            // Success path - return complete data package
            String base64Data = EncodingUtil.base64Encode(documentVersion.VersionData);
            DocumentVerificationUtils.DocumentPayload documentPayload = new DocumentVerificationUtils.DocumentPayload(
                documentVersion.Title, documentVersion.FileExtension, base64Data, documentVersion.ContentSize, documentVersion.LastModifiedDate
            );

            Map<String, Object> recordMap = prepareEducationHistoryPayload(educationHistoryRecord, educationLogId, taskId, documentChecklistItemId);

            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Successfully prepared complete data package for Education Log: ' + educationLogId);
            return new DocumentVerificationUtils.VerificationDataWrapper(recordMap, documentPayload);

        } catch (Exception e) {
            // Catch-all fallback for unexpected errors
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Unexpected error in Education verification: ' + e.getMessage());
            return createFallbackResponse(
                createBasicPayload(educationLogId, 'EducationHistory'),
                'Unexpected error during Education verification: ' + e.getMessage() + '. Please contact system administrator.'
            );
        }
    }

    /**
     * @description Enhanced fetchEducationLog method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     */
    private static ISB_Education_Log__c fetchEducationLog(Id educationLogId) {
        try {
            String soqlQuery = 'SELECT Id, ' + LOG_TO_DETAIL_LOOKUP_FIELD + ', ' + LOG_APPLICATION_LOOKUP_FIELD +
                               ' FROM ' + LOG_OBJECT_API_NAME +
                               ' WHERE Id = :educationLogId LIMIT 1';
            List<ISB_Education_Log__c> educationLogs = Database.query(soqlQuery);
            return educationLogs.isEmpty() ? null : educationLogs[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Education Log record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced fetchEducationHistoryDetailRecord method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     */
    private static hed__Education_History__c fetchEducationHistoryDetailRecord(Id educationHistoryId) {
        try {
            List<hed__Education_History__c> educationHistories = [
                SELECT Id, Name, hed__Contact__c, hed__Contact__r.Name, Institute_Name__c,
                       hed__Educational_Institution_Name__c, hed__End_Date__c, hed__GPA__c, InstituteForDegreeLevel__c,
                       Field_Of_Study_Name__c, Degree__c, hed__Degree_Earned__c, Degree_Level__c,
                       Specialization__c, Programe_Name__c, hed__Start_Date__c, City_Name__c, Country_Name__c, LastModifiedDate
                FROM hed__Education_History__c WHERE Id = :educationHistoryId LIMIT 1
            ];
            return educationHistories.isEmpty() ? null : educationHistories[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Education History record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Returns the DCI Name search criteria based on the degree level.
     * Maintains original method implementation.
     */
    private static String getDciNameCriteriaForDegree(String degreeLevel) {
        if (String.isBlank(degreeLevel)) return null;

        Map<String, String> degreeToDciNameMap = new Map<String, String>{
            'XII' => 'XII Marksheet',
            'Bachelors' => 'UG Marksheet or Transcript',
            'Master' => 'Masters Marksheet or Transcripts',
            'Integrated' => 'Integrated Programme Marksheet',
            'Professional Education' => 'Professional Marksheet or Transcript',
            'Doctorate' => 'PhD/M.Phil Marksheet or Transcripts'
        };

        return degreeToDciNameMap.get(degreeLevel);
    }

    /**
     * @description Finds a DocumentChecklistItem by name, linked to an Application.
     * Enhanced with better error handling.
     */
    private static Id findDocumentChecklistItemByName(Id applicationId, String nameCriteria) {
        try {
            String searchPattern = '%' + nameCriteria + '%';
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
     * @description Enhanced prepareEducationHistoryPayload method.
     * Maintains original method name and signature with null-safe handling.
     */
    private static Map<String, Object> prepareEducationHistoryPayload(hed__Education_History__c educationHistory, Id triggeringLogId, Id taskId, Id dclId) {
        Map<String, Object> payload = new Map<String, Object>();

        payload.put('Id', educationHistory.Id);
        payload.put('triggeringLogId', triggeringLogId);

        payload.put('Task_Id', taskId);
        payload.put('DocumentchecklistItem_Id', dclId);

        payload.put('type', 'EducationHistory');
        payload.put('SF Full Name', (educationHistory.hed__Contact__r != null ? educationHistory.hed__Contact__r.Name : 'Name not available'));
        payload.put('SF Passing Year', (educationHistory.hed__End_Date__c != null ? educationHistory.hed__End_Date__c.year() : null));
        payload.put('To', (educationHistory.hed__End_Date__c != null ? DocumentVerificationUtils.formatDate(educationHistory.hed__End_Date__c) : null));
        payload.put('SF CGPA/Percentage', educationHistory.hed__GPA__c);

        if (educationHistory.Degree_Level__c != 'X' && educationHistory.Degree_Level__c != 'XII') {
            payload.put('SF Field of Study', educationHistory.Field_Of_Study_Name__c);
            payload.put('Major/Specialization', educationHistory.Specialization__c);
        }
        payload.put('Degree/Qualification', educationHistory.Degree__c);
        payload.put('Contact', educationHistory.hed__Contact__c);
        payload.put('From', (educationHistory.hed__Start_Date__c != null ? DocumentVerificationUtils.formatDate(educationHistory.hed__Start_Date__c) : null));
        payload.put('School/Institute/Campus', educationHistory.InstituteForDegreeLevel__c);
        payload.put('degreeLevel', educationHistory.Degree_Level__c);
        payload.put('LastModifiedDate', educationHistory.LastModifiedDate);

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
        payload.put('SF Full Name', 'Data not available');
        payload.put('SF Passing Year', null);
        payload.put('To', null);
        payload.put('SF CGPA/Percentage', null);
        payload.put('SF Field of Study', null);
        payload.put('Major/Specialization', null);
        payload.put('Degree/Qualification', 'Unknown');
        payload.put('Contact', null);
        payload.put('From', null);
        payload.put('School/Institute/Campus', null);
        payload.put('degreeLevel', 'Unknown');
        payload.put('LastModifiedDate', null);

        return payload;
    }
}