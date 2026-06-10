/**
 * @description This Apex class is exposed as a RESTful web service (urlMapping='/documentVerification/*').
 * It handles requests for document verification related to various SObjects like
 * Education History, Employment History, Applications (Contacts ID Proof), and Test Scores.
 * It acts as a router, delegating specific processing to handler classes and using
 * DocumentVerificationUtils for common functionalities.
 * @author Nitish Sinwar
 */
@RestResource(urlMapping='/documentVerification/*')
global with sharing class DocumentVerificationService {

    private static final String MAIN_SERVICE_NAME = 'DOC VERIFICATION SVC';

    // Path prefixes for routing
    private static final String PATH_EDUCATION = 'education';
    private static final String PATH_EMPLOYMENT = 'employment';
    private static final String PATH_APPLICATION = 'application';
    private static final String PATH_TESTSCORE = 'testscore';

    // Record Type identifiers used in request body for type distinction
    private static final String BODY_RECORD_TYPE_APPLICATION = 'Application';
    private static final String BODY_RECORD_TYPE_EMPLOYMENT = 'Employment';
    private static final String BODY_RECORD_TYPE_EDUCATION = 'Education'; // Correctly defined here


    /**
     * @description Handles HTTP POST requests. Routes requests based on URL path or request body
     * parameters to the appropriate verification handler.
     * @input RestRequest req The incoming REST request.
     * @input RestResponse res The outgoing REST response to be populated.
     * @output Populates RestResponse with verification data or an error message.
     */
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String fullRequestURI = req.requestURI;
        String resourceMappingPrefix = '/documentVerification/';
        String relativePath = '';

        Integer mappingPrefixStartIndex = fullRequestURI.indexOf(resourceMappingPrefix);

        if (mappingPrefixStartIndex != -1) {
            relativePath = fullRequestURI.substring(mappingPrefixStartIndex + resourceMappingPrefix.length());
        } else {
            DocumentVerificationUtils.debug(MAIN_SERVICE_NAME, 'Error: Could not find resource mapping prefix "' + resourceMappingPrefix + '" in URI: ' + fullRequestURI);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(DocumentVerificationUtils.createErrorResponseMap('Internal Server Error: Invalid URI configuration.')));
            return;
        }

        List<String> pathParts = relativePath.split('/');

        try {
            if (pathParts.size() == 2 && !String.isBlank(pathParts[1])) {
                handlePathBasedRequest(pathParts, res);
            } else if (String.isBlank(relativePath) || (pathParts.size() == 1 && String.isBlank(pathParts[0]))) {
                handleBodyBasedRequest(req, res);
            } else {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(DocumentVerificationUtils.createErrorResponseMap('Endpoint not found for path: ' + relativePath)));
                DocumentVerificationUtils.debug(MAIN_SERVICE_NAME, 'doPost Error: Endpoint not found for relative path: ' + relativePath + ' (Full URI: ' + fullRequestURI + ')');
            }
        } catch (DocumentVerificationUtils.DocumentVerificationException dve) {
            handleRestException(dve, res, 'DocumentVerificationException');
        } catch (AuraHandledException ahe) { // Catch AuraHandledException if thrown from LWC/Aura via Apex
            handleRestException(ahe, res, 'AuraHandledException');
        } catch (Exception e) {
            handleRestException(e, res, 'GenericException');
        }
    }

    /**
     * @description Routes requests that have a two-part path (e.g., /education/{id}).
     * @param pathParts A list of strings representing parts of the URL path.
     * @param res The RestResponse object to populate.
     * @output Populates RestResponse based on the handled request.
     */
    private static void handlePathBasedRequest(List<String> pathParts, RestResponse res) {
        String recordTypePath = pathParts[0];
        String recordIdStr = pathParts[1];
        Object dataPackage; 

        if (PATH_EDUCATION.equalsIgnoreCase(recordTypePath)) {
            Id educationHistoryId = DocumentVerificationUtils.parseAndValidateId(recordIdStr, EducationVerificationHandler.SOBJECT_API_NAME_FOR_ERROR + ' ID');
            dataPackage = EducationVerificationHandler.getEducationVerificationDataPackage(educationHistoryId);
            sendSuccessResponse(res, dataPackage, 'EducationVerificationWithPathId', educationHistoryId);
        } else if (PATH_EMPLOYMENT.equalsIgnoreCase(recordTypePath)) {
            // The ID passed is now for ISB_Employment_Log__c
            // EmploymentVerificationHandler.SOBJECT_API_NAME_FOR_ERROR is now "ISB Employment Log"
            Id employmentLogId = DocumentVerificationUtils.parseAndValidateId(recordIdStr, EmploymentVerificationHandler.SOBJECT_API_NAME_FOR_ERROR + ' ID');
            dataPackage = EmploymentVerificationHandler.getEmploymentVerificationDataPackage(employmentLogId);
            sendSuccessResponse(res, dataPackage, 'EmploymentVerificationWithPathId', employmentLogId);
        } else if (PATH_APPLICATION.equalsIgnoreCase(recordTypePath)) {
            Id applicationId = DocumentVerificationUtils.parseAndValidateId(recordIdStr, ApplicationVerificationHandler.SOBJECT_API_NAME_FOR_ERROR + ' ID');
            dataPackage = ApplicationVerificationHandler.getApplicationVerificationDataPackage(applicationId);
            sendSuccessResponse(res, dataPackage, 'ApplicationVerificationWithPathId', applicationId);
        } else if (PATH_TESTSCORE.equalsIgnoreCase(recordTypePath)) {
            Id testId = DocumentVerificationUtils.parseAndValidateId(recordIdStr, TestScoreVerificationHandler.SOBJECT_API_NAME_FOR_ERROR + ' ID');
            dataPackage = TestScoreVerificationHandler.getTestScoreVerificationDataPackage(testId);
            sendSuccessResponse(res, dataPackage, 'TestScoreVerificationWithPathId', testId);
        } else {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(DocumentVerificationUtils.createErrorResponseMap('Endpoint not found for path type: ' + recordTypePath)));
            DocumentVerificationUtils.debug(MAIN_SERVICE_NAME, 'handlePathBasedRequest Error: Endpoint not found for path type: ' + recordTypePath);
        }
    }

    /**
     * @description Routes requests where the record ID and type are expected in the request body.
     * @param req The RestRequest object.
     * @param res The RestResponse object to populate.
     * @output Populates RestResponse based on the handled request.
     */
    private static void handleBodyBasedRequest(RestRequest req, RestResponse res) {
        String requestBodyString = req.requestBody != null ? req.requestBody.toString() : null;
        if (String.isBlank(requestBodyString)) {
            throw new DocumentVerificationUtils.DocumentVerificationException(DocumentVerificationUtils.ERROR_PREFIX + 'Request body is empty and required for this endpoint.');
        }

        Map<String, Object> params;
        try {
            params = (Map<String, Object>)JSON.deserializeUntyped(requestBodyString);
        } catch (System.JSONException e) {
            throw new DocumentVerificationUtils.DocumentVerificationException(DocumentVerificationUtils.ERROR_PREFIX + 'Invalid JSON format in request body. Detail: ' + e.getMessage());
        }

        String recordTypeFromBody = params.get('recordType') instanceof String ? (String)params.get('recordType') : null;
        DocumentVerificationUtils.VerificationDataWrapper dataPackage; 
        Id recordId;
        String handlerMethodNameForLog = 'VerificationWithBodyId';
        String recordTypeForLog = recordTypeFromBody;

        if (BODY_RECORD_TYPE_APPLICATION.equalsIgnoreCase(recordTypeFromBody)) {
            recordId = getRecordIdFromParams(params, recordTypeFromBody.toLowerCase() + 'Id', ApplicationVerificationHandler.SOBJECT_API_NAME_FOR_ERROR);
            dataPackage = ApplicationVerificationHandler.getApplicationVerificationDataPackage(recordId);
        } else if (BODY_RECORD_TYPE_EMPLOYMENT.equalsIgnoreCase(recordTypeFromBody)) {
            // The ID passed is now for ISB_Employment_Log__c
            // EmploymentVerificationHandler.SOBJECT_API_NAME_FOR_ERROR is "ISB Employment Log"
            recordId = getRecordIdFromParams(params, recordTypeFromBody.toLowerCase() + 'Id', EmploymentVerificationHandler.SOBJECT_API_NAME_FOR_ERROR);
            dataPackage = EmploymentVerificationHandler.getEmploymentVerificationDataPackage(recordId);
        } else if (BODY_RECORD_TYPE_EDUCATION.equalsIgnoreCase(recordTypeFromBody)) {
            recordId = getRecordIdFromParams(params, recordTypeFromBody.toLowerCase() + 'Id', EducationVerificationHandler.SOBJECT_API_NAME_FOR_ERROR, 'educationHistoryId');
            dataPackage = EducationVerificationHandler.getEducationVerificationDataPackage(recordId);
        } else {
            // Fallback to check specific ID keys
            if (params.containsKey('applicationId')) {
                recordTypeForLog = BODY_RECORD_TYPE_APPLICATION;
                recordId = getRecordIdFromParams(params, 'applicationId', ApplicationVerificationHandler.SOBJECT_API_NAME_FOR_ERROR);
                dataPackage = ApplicationVerificationHandler.getApplicationVerificationDataPackage(recordId);
            } else if (params.containsKey('employmentId')) { // This key 'employmentId' now refers to ISB_Employment_Log__c Id
                recordTypeForLog = BODY_RECORD_TYPE_EMPLOYMENT;
                recordId = getRecordIdFromParams(params, 'employmentId', EmploymentVerificationHandler.SOBJECT_API_NAME_FOR_ERROR);
                dataPackage = EmploymentVerificationHandler.getEmploymentVerificationDataPackage(recordId);
            } else if (params.containsKey('educationHistoryId') || params.containsKey('educationId')) {
                 recordTypeForLog = BODY_RECORD_TYPE_EDUCATION;
                 recordId = getRecordIdFromParams(params, params.containsKey('educationHistoryId') ? 'educationHistoryId' : 'educationId', EducationVerificationHandler.SOBJECT_API_NAME_FOR_ERROR);
                 dataPackage = EducationVerificationHandler.getEducationVerificationDataPackage(recordId);
            } else {
                throw new DocumentVerificationUtils.DocumentVerificationException(DocumentVerificationUtils.ERROR_PREFIX + 'Missing or unsupported "recordType" in request body, or ambiguous ID fields.');
            }
        }
        sendSuccessResponse(res, dataPackage, handlerMethodNameForLog + ' for ' + recordTypeForLog, recordId);
    }

    
    /**
     * @description Helper to extract and validate a record ID from request parameters.
     * @param params The map of request parameters.
     * @param primaryIdKey The primary key to check for the ID (e.g., "applicationId").
     * @param idNameForError User-friendly name for the ID type in error messages.
     * @return The validated Salesforce ID.
     * @throws DocumentVerificationUtils.DocumentVerificationException if ID is missing or invalid.
     */
    private static Id getRecordIdFromParams(Map<String, Object> params, String primaryIdKey, String idNameForError) {
        return getRecordIdFromParams(params, primaryIdKey, idNameForError, null);
    }

    /**
     * @description Helper to extract and validate a record ID from request parameters, with a secondary key check.
     * @param params The map of request parameters.
     * @param primaryIdKey The primary key to check for the ID.
     * @param idNameForError User-friendly name for the ID type in error messages.
     * @param secondaryIdKey An optional secondary key to check if the primary is not found.
     * @return The validated Salesforce ID.
     * @throws DocumentVerificationUtils.DocumentVerificationException if ID is missing or invalid.
     */
    private static Id getRecordIdFromParams(Map<String, Object> params, String primaryIdKey, String idNameForError, String secondaryIdKey) {
        Object recordIdObj = params.get(primaryIdKey);
        if (recordIdObj == null && !String.isBlank(secondaryIdKey)) recordIdObj = params.get(secondaryIdKey);
        if (recordIdObj == null) recordIdObj = params.get('recordId'); // Generic fallback key

        if (recordIdObj == null) {
            throw new DocumentVerificationUtils.DocumentVerificationException(DocumentVerificationUtils.ERROR_PREFIX + 'A specific ID (e.g., \'' +
                primaryIdKey + (String.isBlank(secondaryIdKey) ? '\'' : '\' or \'' + secondaryIdKey + '\'') +
                 ' or \'recordId\') is required in the request body for ' + idNameForError + '.');
        }
        return DocumentVerificationUtils.parseAndValidateId(String.valueOf(recordIdObj), idNameForError + ' ID');
    }
    
    /**
     * @description Sets a standard success (200) response.
     * @param res The RestResponse object.
     * @param dataPackage The data to serialize as the response body.
     * @param operationName A descriptive name of the operation for logging.
     * @param recordId The ID of the record processed, for logging.
     * @output Populates RestResponse with status 200 and serialized dataPackage.
     */
    private static void sendSuccessResponse(RestResponse res, Object dataPackage, String operationName, Id recordId) {
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(dataPackage));
        DocumentVerificationUtils.debug(MAIN_SERVICE_NAME, operationName + ' Success for ID: ' + recordId);
    }

    /**
     * @description Handles HTTP GET requests, specifically for fetching files linked to a record.
     * @input RestRequest req The incoming REST request, expecting a 'recordId' parameter.
     * @input RestResponse res The outgoing REST response.
     * @output Populates RestResponse with a list of FileInfo objects or an error message.
     */
    @HttpGet
    global static void doGetFiles() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            String recordIdStr = req.params.get('recordId');
            // Use DocumentVerificationUtils for ID parsing and file logic
            Id recordId = DocumentVerificationUtils.parseAndValidateId(recordIdStr, 'recordId (for doGetFiles)');
            List<DocumentVerificationUtils.FileInfo> files = DocumentVerificationUtils.getFilesForRecordLogic(recordId);
            sendSuccessResponse(res, files, 'doGetFiles', recordId);
        } catch (DocumentVerificationUtils.DocumentVerificationException dve) {
            handleRestException(dve, res, 'DocumentVerificationException');
        } catch (AuraHandledException ahe) {
            handleRestException(ahe, res, 'AuraHandledException');
        } catch (Exception e) {
            handleRestException(e, res, 'GenericException');
        }
    }
    
    /**
     * @description Centralized method for handling exceptions and setting appropriate HTTP error responses.
     * @param e The exception that occurred.
     * @param res The RestResponse object to populate.
     * @param exceptionType A string indicating the type of exception (e.g., "DocumentVerificationException").
     * @output Populates RestResponse with an error status code and a JSON error message.
     */
    private static void handleRestException(Exception e, RestResponse res, String exceptionType) {
        String logExceptionType = exceptionType;
        // Check if it's one of our specific exceptions or a generic one for logging detail
        if (!(e instanceof DocumentVerificationUtils.DocumentVerificationException) && !(e instanceof AuraHandledException)) {
            logExceptionType = 'GenericException';
        }
        DocumentVerificationUtils.debug(MAIN_SERVICE_NAME, 'Request Failed. Type: ' + logExceptionType + '. Message: ' + e.getMessage() +
            (logExceptionType.equals('GenericException') && e.getStackTraceString() != null ? ' Stack: ' + e.getStackTraceString() : ''));

        String errorMessage = e.getMessage();
        // Strip our standard error prefix if present, for cleaner client-side messages
        if (errorMessage != null && errorMessage.startsWith(DocumentVerificationUtils.ERROR_PREFIX)) {
            errorMessage = errorMessage.substringAfter(DocumentVerificationUtils.ERROR_PREFIX).trim();
        } else if (errorMessage != null && errorMessage.contains('Script-thrown exception')) { // Often from Aura/LWC via Apex
            errorMessage = errorMessage.substringAfter('Script-thrown exception:').trim();
        }

        Integer statusCode = 500; // Default to Internal Server Error
        if (e instanceof DocumentVerificationUtils.DocumentVerificationException) {
            // Set more specific HTTP status codes for our custom exceptions
            if (errorMessage != null) {
                if (errorMessage.contains('not found')) statusCode = 404; // Not Found
                else if (errorMessage.contains('Unsupported file type') ||
                         errorMessage.contains('Document is too large') ||
                         errorMessage.contains('File is empty') ||
                         errorMessage.contains('required') || // Missing required parameters
                         errorMessage.contains('Invalid JSON format') ||
                         errorMessage.contains('Invalid ID format') ||
                         errorMessage.contains('Unsupported record type') || // Bad request from client
                         errorMessage.contains('No Applicant linked') ||
                         errorMessage.contains('No Application linked') ||
                         errorMessage.contains('No DocumentChecklistItem found') ||
                         errorMessage.contains('Missing or unsupported "recordType"')) {
                    statusCode = 400; // Bad Request
                }
            }
        } else if (e.getMessage() != null && e.getMessage().contains('timed out')) { // DML timeout, callout timeout
            statusCode = 504; // Gateway Timeout
        } else if (e.getMessage() != null && (e.getMessage().contains('Failed to connect') || e.getMessage().contains('Unauthorized endpoint'))) { // Callout issues
            statusCode = 503; // Service Unavailable
        } else if (e.getMessage() != null && e.getMessage().toLowerCase().contains('not found')) { // More generic not found
             statusCode = 404;
        }


        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(DocumentVerificationUtils.createErrorResponseMap(DocumentVerificationUtils.ERROR_PREFIX + (String.isBlank(errorMessage) ? 'An unexpected error occurred.' : errorMessage))));
    }
}