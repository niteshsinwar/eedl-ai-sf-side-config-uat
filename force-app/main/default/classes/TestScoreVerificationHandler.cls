/**
 * @description Enhanced Test Score document verification handler with graceful fallback support.
 * Maintains original class name and method signatures while adding internal fallback logic.
 * It handles three data components: Test record, Test Score record, and document.
 * When any component is missing, returns structured error messages instead of throwing exceptions.
 * @author Nitish Sinwar
 * @version Enhanced with Fallback Support (maintains original API)
 */
public without sharing class TestScoreVerificationHandler {
    private static final String HANDLER_SERVICE_NAME = 'TEST_SCORE_HANDLER'; // Convention: SCREAMING_SNAKE_CASE
    // Constants specific to Test Score
    public static final String SOBJECT_API_NAME = 'hed__Test__c';
    public static final String SOBJECT_API_NAME_FOR_TEST_SCORE = 'hed__Test_Score__c';
    public static final String SOBJECT_API_NAME_FOR_ERROR = 'Test Score';

    private static final String DOCUMENT_CHECKLIST_ITEM_API_NAME = 'DocumentChecklistItem';
    private static final String DCI_APPLICATION_LOOKUP_FIELD_API_NAME = 'ParentRecordId';

    private static final Set<String> GMAT_FOCUS_RECORD_TYPE_NAMES   = new Set<String>{'GMAT_FOCUS'};
    private static final Set<String> GMAT_CLASSIC_RECORD_TYPE_NAMES = new Set<String>{'GMAT'};
    private static final String GRE_RECORD_TYPE_NAME = 'GRE';

    // New constant for fallback handling
    private static final String FALLBACK_SUMMARY_KEY = 'Salesforce_data_issue_Summary';

    // Field API names on hed__Test_Score__c
    private static final String TEST_SCORE_FIELD_APPLICATION_C = 'Application__c';
    private static final String TEST_SCORE_FIELD_EMAIL_C = 'Email__c';
    private static final String TEST_SCORE_FIELD_VERBAL_PERCENTILE_C = 'VerbalPercentile__c';
    private static final String TEST_SCORE_FIELD_VERBAL_SCORE_C = 'VerbalScore__c';
    private static final String TEST_SCORE_FIELD_QUANT_PERCENTILE_C = 'QuantPercentile__c';
    private static final String TEST_SCORE_FIELD_QUANT_SCORE_C = 'QuantScore__c';
    private static final String TEST_SCORE_FIELD_DATA_INSIGHTS_PERCENTILE_C = 'Data_Insights_Percentile__c';
    private static final String TEST_SCORE_FIELD_DATA_INSIGHTS_SCORE_C = 'Data_Insights_Score__c';
    private static final String TEST_SCORE_FIELD_TOTAL_PERCENTILE_C = 'Total_Percentile__c';
    private static final String TEST_SCORE_FIELD_TOTAL_SCORE_C = 'Total_Score__c';
    private static final String TEST_SCORE_FIELD_ANALYTICAL_PERCENTILE_C = 'Analytical_Percentile__c';
    private static final String TEST_SCORE_FIELD_ANALYTICAL_SCORE_C = 'Analytical_Score__c';
    private static final String TEST_SCORE_FIELD_IR_PERCENTILE_C = 'IR_Percentile__c';
    private static final String TEST_SCORE_FIELD_IR_SCORE_C = 'IR_Score__c';
    private static final String TEST_SCORE_FIELD_TEST_DATE_C = 'Test_Date__c';
    private static final String TEST_SCORE_FIELD_TEST_ID_C = 'Test_ID__c';
    private static final String TEST_SCORE_FIELD_REGISTRATION_NO_C = 'Registration_No__c';
    private static final String TEST_SCORE_FIELD_BIRTHDATE_C = 'Birthdate__c';
    private static final String TEST_SCORE_FIELD_TESTMODE_C = 'Mode_of_Test_Taken__c';

    // Field API names on hed__Test__c
    private static final String TEST_FIELD_VERBAL_PERCENTILE_C = 'VerbalPercentile__c';
    private static final String TEST_FIELD_VERBAL_SCORE_C = 'VerbalScore__c';
    private static final String TEST_FIELD_QUANT_PERCENTILE_C = 'QuantPercentile__c';
    private static final String TEST_FIELD_QUANT_SCORE_C = 'QuantScore__c';
    private static final String TEST_FIELD_DATA_INSIGHTS_PERCENTILE_C = 'Data_Insights_Percentile__c';
    private static final String TEST_FIELD_DATA_INSIGHTS_SCORE_C = 'Data_Insights_Score__c';
    private static final String TEST_FIELD_TOTAL_PERCENTILE_C = 'Total_Percentile__c';
    private static final String TEST_FIELD_TOTAL_SCORE_C = 'Total_Score__c';
    private static final String TEST_FIELD_ANALYTICAL_PERCENTILE_C = 'Analytical_Percentile__c';
    private static final String TEST_FIELD_ANALYTICAL_SCORE_C = 'Analytical_Score__c';
    private static final String TEST_FIELD_IR_PERCENTILE_C = 'IR_Percentile__c';
    private static final String TEST_FIELD_IR_SCORE_C = 'IR_Score__c';
    private static final String TEST_FIELD_TEST_DATE_C = 'hed__Test_Date__c';
    private static final String TEST_FIELD_TEST_ID_C = 'Test_ID__c';
    private static final String TEST_FIELD_REGISTRATION_NO_C = 'Registration_No__c';
    private static final String TEST_FIELD_EMAIL_C = 'Email__c';
    private static final String TEST_FIELD_RECORD_TYPE_NAME_C = 'RecordTypeName__c';
    private static final String TEST_FIELD_APPLICATION_C = 'Application__c';

    /**
     * @description Enhanced method that provides graceful fallback for test score verification.
     * Maintains the same method name and signature but now handles errors gracefully.
     * Handles three data components: Test record, Test Score record, and document.
     * @param testId The ID of the hed__Test__c record.
     * @return A DocumentVerificationUtils.VerificationDataWrapper containing the record data and document payload or fallback error.
     */
    public static DocumentVerificationUtils.VerificationDataWrapper getTestScoreVerificationDataPackage(Id testId) {
        DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Preparing Test Score data for Test ID: ' + testId);

        try {
            // Input validation with graceful fallback
            if (testId == null) {
                return createFallbackResponse(
                    createBasicPayload(null, 'TestScore'),
                    'Test ID is required for verification.'
                );
            }

            // 1. First get the Test Score ID from the Test record (optional component)
            Id testScoreId = getTestScoreIdFromTest(testId);

            // 2. Query Test record (required component #1)
            SObject testRecord = fetchTestRecord(testId);
            if (testRecord == null) {
                return createFallbackResponse(
                    createBasicPayload(testId, 'TestScore'),
                    'Test record not found in Salesforce. Please verify the Test ID exists and is accessible.'
                );
            }

            // 3. Query Test Score record (optional component #2)
            SObject testScoreRecord;
            String testScoreStatus = 'found';
            if (testScoreId != null) {
                testScoreRecord = fetchTestScoreRecord(testScoreId);
                if (testScoreRecord == null) {
                    testScoreStatus = 'missing';
                }
            } else {
                testScoreStatus = 'missing';
            }

            // If Test Score doesn't exist, create empty SObject for API_* fields
            if (testScoreStatus == 'missing') {
                Schema.SObjectType sType = Schema.getGlobalDescribe().get(SOBJECT_API_NAME_FOR_TEST_SCORE);
                testScoreRecord = sType.newSObject(null, true);
            }

            // 4. Validate Test record fields
            Id applicationId = (Id)testRecord.get(TEST_FIELD_APPLICATION_C);
            String testRecordTypeName = (String)testRecord.get(TEST_FIELD_RECORD_TYPE_NAME_C);

            if (applicationId == null) {
                return createFallbackResponse(
                    createBasicPayload(testId, 'TestScore'),
                    'No Application is linked to this Test record. Please ensure the Application field is populated.'
                );
            }

            if (String.isBlank(testRecordTypeName)) {
                return createFallbackResponse(
                    createBasicPayload(testId, 'TestScore'),
                    'RecordTypeName__c is missing on Test record. Please ensure the Record Type is properly configured.'
                );
            }

            // 5. Get Applicant details (birthdate and name) with a single query
            Map<String, Object> applicantInfo = getApplicantBirthdateAndName(applicationId);
            Date applicantBirthdate = (Date) applicantInfo.get('Birthdate');
            String applicantName = (String) applicantInfo.get('Name');

            // 6. Fetch related Task ID
            List<Task> tasks = [
                SELECT Id FROM Task
                WHERE WhatId = :applicationId AND Subject LIKE '%Test Score%'
                LIMIT 1
            ];
            Id taskId = tasks.isEmpty() ? null : tasks[0].Id;

            // 7. Determine DCI Name based on Test Record Type
            String dciNameCriteria;
            if (GMAT_CLASSIC_RECORD_TYPE_NAMES.contains(testRecordTypeName.toUpperCase())) {
                dciNameCriteria = 'GMAT Score Card';
            } else if (GMAT_FOCUS_RECORD_TYPE_NAMES.contains(testRecordTypeName.toUpperCase())) {
                dciNameCriteria = 'GMAT Score Card';
            } else if (GRE_RECORD_TYPE_NAME.equalsIgnoreCase(testRecordTypeName)) {
                dciNameCriteria = 'GRE Score Card';
            } else {
                Map<String, Object> partialPayload = prepareTestScorePayload(testScoreRecord, testRecord, testRecordTypeName, taskId, null, applicantBirthdate, applicantName);
                return createFallbackResponse(
                    partialPayload,
                    'Unsupported Test RecordTypeName__c for document verification: ' + testRecordTypeName + '. Supported types are: GMAT, GMAT_FOCUS, GRE.'
                );
            }

            // 8. Find DocumentChecklistItem (required component #3)
            Id documentChecklistItemId = findDocumentChecklistItemId(applicationId, dciNameCriteria);
            if (documentChecklistItemId == null) {
                Map<String, Object> partialPayload = prepareTestScorePayload(testScoreRecord, testRecord, testRecordTypeName, taskId, null, applicantBirthdate, applicantName);
                return createFallbackResponse(
                    partialPayload,
                    'Required test score document not found. Expected document type: "' + dciNameCriteria + '" for Application ID: ' + applicationId + '. Please ensure the score card is uploaded correctly.'
                );
            }

            // 9. Attempt to fetch document with graceful fallback (required component #4)
            ContentVersion documentVersion = null;
            String documentError = null;

            try {
                documentVersion = DocumentVerificationUtils.fetchLatestDocumentVersion(
                    documentChecklistItemId,
                    testRecordTypeName + ' Score Card Document'
                );

                if (documentVersion == null) {
                    documentError = 'No test score document attached to the DocumentChecklistItem. Expected document type: ' + dciNameCriteria + '. Please upload the required score card.';
                } else {
                    DocumentVerificationUtils.validateDocument(documentVersion);
                }
            } catch (Exception docException) {
                documentError = 'Document retrieval failed for test score verification: ' + docException.getMessage() + '. Please check the document attachment and try again.';
            }

            // If document issues, return fallback response with complete payload
            if (documentError != null) {
                Map<String, Object> fallbackPayload = prepareTestScorePayload(testScoreRecord, testRecord, testRecordTypeName, taskId, documentChecklistItemId, applicantBirthdate, applicantName);

                // Add specific note about missing Test Score record if applicable
                if (testScoreStatus == 'missing') {
                    documentError += ' Note: Test Score record is also missing - only applicant-entered data is available for verification.';
                }

                return createFallbackResponse(fallbackPayload, documentError);
            }

            // Success path - return complete data package
            String base64Data = EncodingUtil.base64Encode(documentVersion.VersionData);
            DocumentVerificationUtils.DocumentPayload documentPayload = new DocumentVerificationUtils.DocumentPayload(
                documentVersion.Title, documentVersion.FileExtension, base64Data, documentVersion.ContentSize, documentVersion.LastModifiedDate
            );

            Map<String, Object> recordMap = prepareTestScorePayload(testScoreRecord, testRecord, testRecordTypeName, taskId, documentChecklistItemId, applicantBirthdate, applicantName);

            // Log success with component status
            String successMessage = 'Successfully prepared complete data package for Test: ' + testId + ' (Test Score: ' + testScoreStatus + ')';
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, successMessage);

            return new DocumentVerificationUtils.VerificationDataWrapper(recordMap, documentPayload);

        } catch (Exception e) {
            // Catch-all fallback for unexpected errors
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Unexpected error in Test Score verification: ' + e.getMessage());
            return createFallbackResponse(
                createBasicPayload(testId, 'TestScore'),
                'Unexpected error during Test Score verification: ' + e.getMessage() + '. Please contact system administrator.'
            );
        }
    }

    // NEW: single roundtrip for Applicant Birthdate and Name
    private static Map<String, Object> getApplicantBirthdateAndName(Id applicationId) {
        Map<String, Object> result = new Map<String, Object>{ 'Birthdate' => null, 'Name' => null };
        try {
            List<SObject> rows = Database.query(
                'SELECT hed__Applicant__r.Birthdate, hed__Applicant__r.Name FROM hed__Application__c WHERE Id = :applicationId LIMIT 1'
            );
            if (rows.isEmpty()) return result;
            SObject a = rows[0].getSObject('hed__Applicant__r');
            if (a != null) {
                result.put('Birthdate', (Date)a.get('Birthdate'));
                result.put('Name', (String)a.get('Name'));
            }
            return result;
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Applicant details: ' + e.getMessage());
            return result;
        }
    }

    /**
     * @description Enhanced getTestScoreIdFromTest method with graceful error handling.
     * Now returns null instead of throwing exceptions.
     */
    private static Id getTestScoreIdFromTest(Id testId) {
        try {
            String soqlQuery = 'SELECT Id FROM ' + SOBJECT_API_NAME_FOR_TEST_SCORE +
                              ' WHERE hed__Test__c = :testId LIMIT 1';
            List<SObject> testScoreRecords = Database.query(soqlQuery);
            return testScoreRecords.isEmpty() ? null : testScoreRecords[0].Id;
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Test Score ID: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced fetchTestRecord method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     */
    private static SObject fetchTestRecord(Id testId) {
        try {
            String soqlQuery = 'SELECT Id, LastModifiedDate, ' +
                TEST_FIELD_RECORD_TYPE_NAME_C + ', ' +
                TEST_FIELD_APPLICATION_C + ', ' +
                TEST_FIELD_VERBAL_PERCENTILE_C + ', ' +
                TEST_FIELD_VERBAL_SCORE_C + ', ' +
                TEST_FIELD_QUANT_PERCENTILE_C + ', ' +
                TEST_FIELD_QUANT_SCORE_C + ', ' +
                TEST_FIELD_DATA_INSIGHTS_PERCENTILE_C + ', ' +
                TEST_FIELD_DATA_INSIGHTS_SCORE_C + ', ' +
                TEST_FIELD_TOTAL_PERCENTILE_C + ', ' +
                TEST_FIELD_TOTAL_SCORE_C + ', ' +
                TEST_FIELD_ANALYTICAL_PERCENTILE_C + ', ' +
                TEST_FIELD_ANALYTICAL_SCORE_C + ', ' +
                TEST_FIELD_IR_PERCENTILE_C + ', ' +
                TEST_FIELD_IR_SCORE_C + ', ' +
                TEST_FIELD_TEST_DATE_C + ', ' +
                TEST_FIELD_TEST_ID_C + ', ' +
                TEST_FIELD_REGISTRATION_NO_C + ', ' +
                TEST_FIELD_EMAIL_C +
                ' FROM ' + SOBJECT_API_NAME +
                ' WHERE Id = :testId LIMIT 1';

            List<SObject> testRecords = Database.query(soqlQuery);
            return testRecords.isEmpty() ? null : testRecords[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Test record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced fetchTestScoreRecord method with graceful error handling.
     * Now returns null instead of throwing exceptions when record not found.
     */
    private static SObject fetchTestScoreRecord(Id testScoreId) {
        try {
            String soqlQuery = 'SELECT Id, ' +
                TEST_SCORE_FIELD_APPLICATION_C + ', ' +
                TEST_SCORE_FIELD_EMAIL_C + ', ' +
                TEST_SCORE_FIELD_VERBAL_PERCENTILE_C + ', ' +
                TEST_SCORE_FIELD_VERBAL_SCORE_C + ', ' +
                TEST_SCORE_FIELD_QUANT_PERCENTILE_C + ', ' +
                TEST_SCORE_FIELD_QUANT_SCORE_C + ', ' +
                TEST_SCORE_FIELD_DATA_INSIGHTS_PERCENTILE_C + ', ' +
                TEST_SCORE_FIELD_DATA_INSIGHTS_SCORE_C + ', ' +
                TEST_SCORE_FIELD_TOTAL_PERCENTILE_C + ', ' +
                TEST_SCORE_FIELD_TOTAL_SCORE_C + ', ' +
                TEST_SCORE_FIELD_ANALYTICAL_PERCENTILE_C + ', ' +
                TEST_SCORE_FIELD_ANALYTICAL_SCORE_C + ', ' +
                TEST_SCORE_FIELD_IR_PERCENTILE_C + ', ' +
                TEST_SCORE_FIELD_IR_SCORE_C + ', ' +
                TEST_SCORE_FIELD_TEST_DATE_C + ', ' +
                TEST_SCORE_FIELD_TEST_ID_C + ', ' +
                TEST_SCORE_FIELD_REGISTRATION_NO_C + ', ' +
                TEST_SCORE_FIELD_BIRTHDATE_C + ', ' +
                TEST_SCORE_FIELD_TESTMODE_C + ', ' +
                'hed__Test__c' +
                ' FROM ' + SOBJECT_API_NAME_FOR_TEST_SCORE +
                ' WHERE Id = :testScoreId LIMIT 1';

            List<SObject> testScoreRecords = Database.query(soqlQuery);
            return testScoreRecords.isEmpty() ? null : testScoreRecords[0];
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error fetching Test Score record: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced getApplicantBirthdate method with graceful error handling.
     * Deprecated in favor of getApplicantBirthdateAndName to reduce SOQL calls.
     */
    private static Date getApplicantBirthdate(Id applicationId) {
        Map<String, Object> info = getApplicantBirthdateAndName(applicationId);
        return (Date) info.get('Birthdate');
    }

    /**
     * @description Enhanced findDocumentChecklistItemId method with better error handling.
     * Maintains original method logic with improved error handling.
     */
    private static Id findDocumentChecklistItemId(Id applicationId, String dciNameCriteria) {
        try {
            String searchPattern = '%' + dciNameCriteria + '%';
            String soqlQuery = 'SELECT Id FROM ' + DOCUMENT_CHECKLIST_ITEM_API_NAME +
                           ' WHERE ' + DCI_APPLICATION_LOOKUP_FIELD_API_NAME + ' = :applicationId ' +
                           ' AND Name LIKE :searchPattern ' +
                           ' ORDER BY CreatedDate DESC LIMIT 1';
            List<SObject> dciItems = Database.query(soqlQuery);
            return dciItems.isEmpty() ? null : dciItems[0].Id;
        } catch (Exception e) {
            DocumentVerificationUtils.debug(HANDLER_SERVICE_NAME, 'Error querying DocumentChecklistItem: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Enhanced prepareTestScorePayload method.
     * Maintains original method name and signature with null-safe handling.
     */
    private static Map<String, Object> prepareTestScorePayload(
        SObject testScoreRecord,
        SObject testRecord,
        String testRecordTypeName,
        Id taskId,
        Id dclId,
        Date applicantBirthdate,
        String applicantName
    ) {
        Map<String, Object> payload = new Map<String, Object>();

        // Basic record information
        payload.put('recordId', testRecord.Id);  // Primary record ID is Test record
        payload.put('type', 'TestScore');
        payload.put('Task_Id', taskId);
        payload.put('DocumentchecklistItem_Id', dclId);
        payload.put('RecordTypeName__c', testRecordTypeName);
        payload.put('LastModifiedDate', testRecord.get('LastModifiedDate'));

        payload.put('Test_Mode', testScoreRecord.get(TEST_SCORE_FIELD_TESTMODE_C));

        // Common fields for verification comparison
        // Applicant-entered values (from Test record) - prefixed with "Applicant_"
        payload.put('Applicant_Test_Date', testRecord.get(TEST_FIELD_TEST_DATE_C));
        payload.put('Applicant_Email', testRecord.get(TEST_FIELD_EMAIL_C));
        payload.put('Applicant_Registration_No', testRecord.get(TEST_FIELD_REGISTRATION_NO_C));
        payload.put('Applicant_VerbalPercentile', testRecord.get(TEST_FIELD_VERBAL_PERCENTILE_C));
        payload.put('Applicant_VerbalScore', testRecord.get(TEST_FIELD_VERBAL_SCORE_C));
        payload.put('Applicant_QuantPercentile', testRecord.get(TEST_FIELD_QUANT_PERCENTILE_C));
        payload.put('Applicant_QuantScore', testRecord.get(TEST_FIELD_QUANT_SCORE_C));
        payload.put('Applicant_Total_Score', testRecord.get(TEST_FIELD_TOTAL_SCORE_C));
        payload.put('Applicant_Total_Percentile', testRecord.get(TEST_FIELD_TOTAL_PERCENTILE_C));

        // API-fetched values (from Test Score record) - prefixed with "API_"
        payload.put('API_Test_Date', testScoreRecord.get(TEST_SCORE_FIELD_TEST_DATE_C));
        payload.put('API_Email', testScoreRecord.get(TEST_SCORE_FIELD_EMAIL_C));
        payload.put('API_Registration_No', testScoreRecord.get(TEST_SCORE_FIELD_REGISTRATION_NO_C));
        payload.put('API_VerbalPercentile', testScoreRecord.get(TEST_SCORE_FIELD_VERBAL_PERCENTILE_C));
        payload.put('API_VerbalScore', testScoreRecord.get(TEST_SCORE_FIELD_VERBAL_SCORE_C));
        payload.put('API_QuantPercentile', testScoreRecord.get(TEST_SCORE_FIELD_QUANT_PERCENTILE_C));
        payload.put('API_QuantScore', testScoreRecord.get(TEST_SCORE_FIELD_QUANT_SCORE_C));
        payload.put('API_Total_Score', testScoreRecord.get(TEST_SCORE_FIELD_TOTAL_SCORE_C));
        payload.put('API_Total_Percentile', testScoreRecord.get(TEST_SCORE_FIELD_TOTAL_PERCENTILE_C));

        // Birthdate and identity information
        payload.put('API_Birthdate', testScoreRecord.get(TEST_SCORE_FIELD_BIRTHDATE_C));
        payload.put('Applicant_Birthdate', applicantBirthdate);
        payload.put('Applicant_Name', applicantName);
        payload.put('API_Name', null); // API has no name field by design

        // Test-type-specific fields
        if (GRE_RECORD_TYPE_NAME.equalsIgnoreCase(testRecordTypeName)) {
            // GRE: Analytical
            payload.put('Applicant_Analytical_Percentile', testRecord.get(TEST_FIELD_ANALYTICAL_PERCENTILE_C));
            payload.put('Applicant_Analytical_Score', testRecord.get(TEST_FIELD_ANALYTICAL_SCORE_C));
            payload.put('API_Analytical_Percentile', testScoreRecord.get(TEST_SCORE_FIELD_ANALYTICAL_PERCENTILE_C));
            payload.put('API_Analytical_Score', testScoreRecord.get(TEST_SCORE_FIELD_ANALYTICAL_SCORE_C));

        } else if (GMAT_CLASSIC_RECORD_TYPE_NAMES.contains(testRecordTypeName.toUpperCase())) {
            // GMAT Classic: Analytical + IR + Test ID
            payload.put('Applicant_Test_ID', testRecord.get(TEST_FIELD_TEST_ID_C));
            payload.put('Applicant_Analytical_Percentile', testRecord.get(TEST_FIELD_ANALYTICAL_PERCENTILE_C));
            payload.put('Applicant_Analytical_Score', testRecord.get(TEST_FIELD_ANALYTICAL_SCORE_C));
            payload.put('Applicant_IR_Percentile', testRecord.get(TEST_FIELD_IR_PERCENTILE_C));
            payload.put('Applicant_IR_Score', testRecord.get(TEST_FIELD_IR_SCORE_C));
            payload.put('API_Test_ID', testScoreRecord.get(TEST_SCORE_FIELD_TEST_ID_C));
            payload.put('API_Analytical_Percentile', testScoreRecord.get(TEST_SCORE_FIELD_ANALYTICAL_PERCENTILE_C));
            payload.put('API_Analytical_Score', testScoreRecord.get(TEST_SCORE_FIELD_ANALYTICAL_SCORE_C));
            payload.put('API_IR_Percentile', testScoreRecord.get(TEST_SCORE_FIELD_IR_PERCENTILE_C));
            payload.put('API_IR_Score', testScoreRecord.get(TEST_SCORE_FIELD_IR_SCORE_C));

        } else if (GMAT_FOCUS_RECORD_TYPE_NAMES.contains(testRecordTypeName.toUpperCase())) {
            // GMAT Focus: Data Insights + Test ID
            payload.put('Applicant_Test_ID', testRecord.get(TEST_FIELD_TEST_ID_C));
            payload.put('Applicant_Data_Insights_Percentile', testRecord.get(TEST_FIELD_DATA_INSIGHTS_PERCENTILE_C));
            payload.put('Applicant_Data_Insights_Score', testRecord.get(TEST_FIELD_DATA_INSIGHTS_SCORE_C));
            payload.put('API_Test_ID', testScoreRecord.get(TEST_SCORE_FIELD_TEST_ID_C));
            payload.put('API_Data_Insights_Percentile', testScoreRecord.get(TEST_SCORE_FIELD_DATA_INSIGHTS_PERCENTILE_C));
            payload.put('API_Data_Insights_Score', testScoreRecord.get(TEST_SCORE_FIELD_DATA_INSIGHTS_SCORE_C));
        }

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
        payload.put('Task_Id', null);
        payload.put('DocumentchecklistItem_Id', null);
        payload.put('RecordTypeName__c', 'Unknown');
        payload.put('LastModifiedDate', null);
        payload.put('Test_Mode', null);

        // Applicant-entered values
        payload.put('Applicant_Test_Date', null);
        payload.put('Applicant_Email', 'Data not available');
        payload.put('Applicant_Name', null);
        payload.put('Applicant_Registration_No', null);
        payload.put('Applicant_VerbalPercentile', null);
        payload.put('Applicant_VerbalScore', null);
        payload.put('Applicant_QuantPercentile', null);
        payload.put('Applicant_QuantScore', null);
        payload.put('Applicant_Total_Score', null);
        payload.put('Applicant_Total_Percentile', null);
        payload.put('Applicant_Birthdate', null);

        // API-fetched values
        payload.put('API_Test_Date', null);
        payload.put('API_Email', null);
        payload.put('API_Name', null);
        payload.put('API_Registration_No', null);
        payload.put('API_VerbalPercentile', null);
        payload.put('API_VerbalScore', null);
        payload.put('API_QuantPercentile', null);
        payload.put('API_QuantScore', null);
        payload.put('API_Total_Score', null);
        payload.put('API_Total_Percentile', null);
        payload.put('API_Birthdate', null);

        return payload;
    }
}