/* @description This class handles the processing of AI server jobs related to application verification.
 * It processes job records, updates related tasks and document checklist items based on verification summaries,
 * and manages the status of applications based on verification results.
 * The class is designed to be used in a trigger context for after insert and after update events.
 * @author Nitish Sinwar
 */

public class AIServerJobTriggerHandler {
    
    // Enhanced: Added new verification types for resume, recommender, and declaration
    private static final Map<String, String> VERIFICATION_TYPES = new Map<String, String>{
        'EDUCATION' => 'education',
        'TEST_SCORE' => 'test score',
        'EMPLOYMENT' => 'employment',
        'PERSONAL_DETAILS' => 'personal detail',
        'RESUME_ANALYSIS' => 'resume',
        'RECOMMENDER_ANALYSIS' => 'recommender',
        'DECLARATION_ANALYSIS' => 'declaration'
    };
     
    private static final Set<String> EXCLUDED_FROM_AUTO_UPDATE = new Set<String>{
        'EDUCATION', 'TEST_SCORE', 'EMPLOYMENT'
    };
    // Category: retriable, no escalation. These are normally transient queue,
    // worker, or LLM-output failures where another scheduler pass can succeed.
    private static final Set<String> RETRY_ERROR_PATTERNS = new Set<String>{
        '(^|[^a-z0-9])crew([^a-z0-9]|$)',
        '(^|[^a-z0-9])jwt([^a-z0-9]|$)',
        '(^|[^a-z0-9])session([^a-z0-9]|$)',
        'expir',
        'server error.*internal server error',
        'server error.*too many requests',
        'queue full',
        'worker process error',
        'worker process failed',
        'failed to spawn worker process',
        'produced no output',
        'invalid result structure',
        'worker communication failed',
        'maximum execution time',
        'ai model failed during ocr processing',
        'smart extraction failed',
        'could not extract json from llm response',
        'failed to decode json',
        'validation errors for validated.*report',
        'pydantic.*validation',
        'field required.*pydantic',
        'graph execution did not return a valid report',
        'graph execution failed to produce final report',
        'failed to produce final report',
        'crew task failed',
        'crew execution failed'
    };
    // Category: non-retriable, escalation required. These usually indicate the
    // callout path, certificates, network, quota, or service credentials are
    // broken and more jobs will continue failing until the system is fixed.
    private static final Set<String> ALERT_DOWN_PATTERNS = new Set<String>{
        'pkix',
        'certificate_unknown',
        'certification path',
        'unable to tunnel through proxy',
        'proxy returns',
        'read timed out',
        'read timeout',
        'connect timeout',
        'timed out',
        'timeout',
        'connection refused',
        'connection reset',
        'connection aborted',
        'failed to establish a new connection',
        'max retries exceeded',
        'remote disconnected',
        'remotedisconnected',
        'remote end closed connection',
        'host unreachable',
        'service unavailable',
        'temporarily unavailable',
        'dns',
        'name resolution',
        'ssl',
        'api key not valid',
        'permission denied',
        'failed_precondition',
        'salesforce client credentials must be set',
        'client credentials token request failed',
        'failed to retrieve access_token',
        'no apex endpoint path configured',
        'salesforce client session not properly initialized',
        'failed to query for existing ai server job',
        'failed to update/create ai server job record',
        'upsert for ai server job record failed'
    };
    private static final Set<String> ALERT_QUOTA_PATTERNS = new Set<String>{
        'quota exceeded',
        'rate limit',
        'resource exhausted',
        'requests per minute',
        'tokens per minute',
        '(^|[^0-9])429([^0-9]|$)'
    };
    // Category: non-retriable, no escalation. These are usually limited to the
    // individual source record or document payload and need record cleanup.
    private static final Set<String> NON_RETRY_ERROR_PATTERNS = new Set<String>{
        'invalid salesforce record_id format',
        'invalid application_id format',
        'invalid opportunity_id format',
        'invalid salesforce id format',
        'no processing record found',
        'document payload was missing',
        'contact id is missing',
        'could not identify the underlying',
        'document content \\(base64\\) or file extension missing',
        'file has not been decrypted',
        'invalid base64 input',
        'unsupported file format',
        'unable to process input image',
        'input token count exceeds',
        'maximum number of tokens allowed',
        'context is too long',
        'context too long',
        'no attached document found',
        'could not find any contentdocumentlink',
        'found contentversion.*no.*versiondata',
        'contentversion.*no versiondata',
        'no id document file found',
        'no aadhaar/passport file found',
        'no document file matched',
        'opportunity .* not found',
        'opportunity .* has no contact lookup',
        'education record .* not found',
        '404 client error: not found',
        'missing document or invalid data',
        'invalid argument',
        'nonetype.*invoke'
    };

    // Constants
    private static final String COMPLETED_STATUS = 'Completed';
    private static final String INCOMPLETED_STATUS = 'Need Input';
    private static final String APPROVED_STATUS = 'Accepted';
    private static final String PENDING_STATUS = 'Not Verified';
    private static final Decimal HUNDRED_PERCENT = 100;
    private static final String STATUS_FAILED = 'failed';
    private static final String STATUS_QUEUED = 'queued';

    private static final Set<String> PROCESSING_COMPLETE_STATUSES = new Set<String>{'completed'};

    /**
     * @description Defines which DocumentChecklistItem document types should have immutable status protection.
     * This prevents the system from overwriting manually approved records for specific document categories.
     * Current scope: Resume documents only.
     * Future: Add other document types as needed (e.g., 'Proof of Identity', 'Marksheet').
     */
    private static final Set<String> IMMUTABLE_DCI_DOCUMENT_NAMES = new Set<String>{
        'resume' // Case-insensitive matching via .toLowerCase()
        // Add more document name keywords here in future (e.g., 'identity', 'marksheet')
    };

    /**
     * @description Defines which statuses should be protected from auto-updates for configured document types.
     * Use case: Once a resume is marked as 'Accepted', it should not be reverted to 'Not Verified' by automated processes.
     */
    private static final Set<String> IMMUTABLE_DCI_STATUSES = new Set<String>{
        'Accepted'
        // Add more statuses here if needed (e.g., 'Manually Reviewed', 'Locked')
    };
    
    public void handleAfterInsert(List<AI_Server_Job__c> newRecords) {
        if (isApplicationChecklistUpdationEnabled()) {
            processAIServerJobs(newRecords);
        }
    }
  

    public void handleBeforeUpdateInsert( List<AI_Server_Job__c> newList) {
        for (AI_Server_Job__c newRec : newList) {

            if (newRec.Status__c == STATUS_FAILED ) {

                String details = (newRec.Message__c != null) ? newRec.Message__c.toLowerCase() : '';
                Boolean isAlertError = false;

                // Classify current Python API failures before falling back to retry.
                // Terminal data/config/document problems should remain failed even if a nested
                // provider response contains an old generic "internal server error" string.
                if (!String.isBlank(details)) {
                    if (matchesAnyPattern(details, NON_RETRY_ERROR_PATTERNS)) {
                        continue;
                    }
                    if (matchesAnyPattern(details, ALERT_DOWN_PATTERNS)) {
                        sendOperationalAlert('DOWN', newRec);
                        isAlertError = true;
                    } else if (matchesAnyPattern(details, ALERT_QUOTA_PATTERNS)) {
                        sendOperationalAlert('QUOTA', newRec);
                        isAlertError = true;
                    }
                }

                // Only requeue if not an alert-worthy error
                if (!isAlertError && matchesAnyPattern(details, RETRY_ERROR_PATTERNS)) {
                    newRec.Status__c = STATUS_QUEUED;
                }
            }
        }
    }

    private static Boolean matchesAnyPattern(String haystack, Set<String> regexPatterns) {
        String normalized = (haystack == null) ? '' : haystack.toLowerCase();
        for (String regex : regexPatterns) {
            if (String.isBlank(regex)) continue;
            try {
                if (Pattern.compile(regex).matcher(normalized).find()) {
                    return true;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Invalid AI Server error pattern ignored: ' + regex);
            }
        }
        return false;
    }

    private class AlertCtx {
        String recordId;
        String recordName;
        String recordLabel;
    }
       
    private static void sendOperationalAlert(String type, AI_Server_Job__c job) {
        AlertCtx ctx = buildAlertContext(job);

        // Fetch recipients from CMDT (with names for personalization)
        List<AI_Server_Alert_Recipent__mdt> rows;
        try {
            rows = [
                SELECT Email__c, MasterLabel
                FROM AI_Server_Alert_Recipent__mdt
                WHERE  Type__c = :type
            ];
        } catch (Exception e) {
            return; // CMDT not present yet
        }
        if (rows.isEmpty()) return;

        String createdStr = String.valueOf(job.CreatedDate);

        // Subjects per your exact spec
        String subjectDown  = '[AISever][Alert:Down] Server/network issue';
        String subjectQuota = '[AISever][Alert:Quota] LLM provider quota exceeded';
        String subject = (type == 'DOWN') ? subjectDown : subjectQuota;

        // Bodies per your exact spec (with personalization & context)
        for (AI_Server_Alert_Recipent__mdt r : rows) {
            if (String.isBlank(r.Email__c)) continue;
            String name = String.isBlank(r.MasterLabel) ? 'Team' : r.MasterLabel.trim();

            String body;
            if (type == 'DOWN') {
                body =
                    'Dear ' + name + ',\n\n' +
                    'The AI verification process has failed for the following record:\n\n' +
                    '- Source Type: ' + ctx.recordLabel + '\n' +
                    '- Record Name: ' + (String.isBlank(ctx.recordName) ? '(Unknown)' : ctx.recordName) + '\n' +
                    '- Record Id: ' + (String.isBlank(ctx.recordId) ? '(Unknown)' : ctx.recordId) + '\n' +
                    '- Created Date: ' + createdStr + '\n\n' +
                    'Reason:\n' +
                    'Due to a technical issue in the AI Verification Microservice (server/network downtime).\n\n' +
                    'Regards,\n' +
                    'AI Server Monitoring System';
            } else { // QUOTA
                body =
                    'Dear ' + name + ',\n\n' +
                    'The AI verification process has failed for the following record:\n\n' +
                    '- Source Type: ' + ctx.recordLabel + '\n' +
                    '- Record Name: ' + (String.isBlank(ctx.recordName) ? '(Unknown)' : ctx.recordName) + '\n' +
                    '- Record Id: ' + (String.isBlank(ctx.recordId) ? '(Unknown)' : ctx.recordId) + '\n' +
                    '- Created Date: ' + createdStr + '\n\n' +
                    'Reason:\n' +
                    'The Gemini API quota/usage limit has been exceeded, which prevented further verification.\n\n' +
                    'Regards,\n' +
                    'AI Server Monitoring System';
            }

            try {
                sendEmail(r.Email__c.trim(), subject, body);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to send AI Server operational alert: ' + e.getMessage());
            }
        }
    }

    @TestVisible
    private static AlertCtx buildAlertContext(AI_Server_Job__c job) {
        AlertCtx ctx = new AlertCtx();
        ctx.recordLabel = 'Unknown';

        if (job.Application__c != null) {
            ctx.recordId = String.valueOf(job.Application__c);
            ctx.recordLabel = 'Admissions Application';
            List<hed__Application__c> applications = [
                SELECT Id, Name
                FROM hed__Application__c
                WHERE Id = :job.Application__c
                LIMIT 1
            ];
            if (!applications.isEmpty()) {
                ctx.recordName = applications[0].Name;
            }
        } else if (job.Opportunity__c != null) {
            ctx.recordId = String.valueOf(job.Opportunity__c);
            ctx.recordLabel = 'EEDL Opportunity';
            List<Opportunity> opportunities = [
                SELECT Id, Name
                FROM Opportunity
                WHERE Id = :job.Opportunity__c
                LIMIT 1
            ];
            if (!opportunities.isEmpty()) {
                ctx.recordName = opportunities[0].Name;
            }
        } else {
            ctx.recordId = String.valueOf(job.Id);
            ctx.recordLabel = 'AI Server Job';
        }

        return ctx;
    }

private static void sendEmail(String toAddress, String subject, String body) {
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new String[]{ toAddress });
    mail.setSubject(subject);
    mail.setPlainTextBody(body);
 
    // Use org-wide email address
    OrgWideEmailAddress owea = [
        SELECT Id 
        FROM OrgWideEmailAddress 
        WHERE Address = 'applicationhelp@isb.edu' 
        LIMIT 1
    ];
    mail.setOrgWideEmailAddressId(owea.Id);
 
    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }, false);
}


    public void handleAfterUpdate(List<AI_Server_Job__c> newRecords, Map<Id, AI_Server_Job__c> oldMap) {
        List<AI_Server_Job__c> recordsToProcess = getStatusChangedRecords(newRecords, oldMap);
        if (!recordsToProcess.isEmpty() && isApplicationChecklistUpdationEnabled()) {
            processAIServerJobs(recordsToProcess);
        }
    }

    private static Boolean isApplicationChecklistUpdationEnabled() {
        if (Test.isRunningTest()) {
            return true;
        }
        AI_Server_ChokePoint__mdt chokePoint = [
            SELECT DeveloperName, Is_Enabled__c
            FROM AI_Server_ChokePoint__mdt
            WHERE DeveloperName = 'Application_Checklist_Updation'
            LIMIT 1
        ];
        return chokePoint != null && chokePoint.Is_Enabled__c;
    }
    
    private List<AI_Server_Job__c> getStatusChangedRecords(List<AI_Server_Job__c> newRecords, 
                                                          Map<Id, AI_Server_Job__c> oldMap) {
        List<AI_Server_Job__c> recordsToProcess = new List<AI_Server_Job__c>();
        for (AI_Server_Job__c newRecord : newRecords) {
            AI_Server_Job__c oldRecord = oldMap.get(newRecord.Id);
            if (isStatusChangedToProcessingComplete(newRecord, oldRecord)) {
                recordsToProcess.add(newRecord);
            }
        }
        return recordsToProcess;
    }
    
    private Boolean isStatusChangedToProcessingComplete(AI_Server_Job__c newRecord, AI_Server_Job__c oldRecord) {
        return PROCESSING_COMPLETE_STATUSES.contains(newRecord.Status__c) && 
               (!PROCESSING_COMPLETE_STATUSES.contains(oldRecord.Status__c) || oldRecord.Status__c == null);
    }
    
    private void processAIServerJobs(List<AI_Server_Job__c> aiServerJobs) {
        List<AI_Server_Job__c> validJobs = getValidProcessedJobs(aiServerJobs);
        if (validJobs.isEmpty()) return;
        
        Set<Id> applicationIds = getApplicationIds(validJobs);
        
        try {
            for (String verificationType : VERIFICATION_TYPES.keySet()) {
               // MODIFIED: Skip processing for excluded verification types
               if (EXCLUDED_FROM_AUTO_UPDATE.contains(verificationType)) {
                   continue;
               }
                processVerificationTypeForAllScenarios(applicationIds, verificationType);
            }
        } catch (Exception e) {
            handleException('processAIServerJobs', e);
        }
    }
    
    private List<AI_Server_Job__c> getValidProcessedJobs(List<AI_Server_Job__c> aiServerJobs) {
        List<AI_Server_Job__c> validJobs = new List<AI_Server_Job__c>();
        for (AI_Server_Job__c job : aiServerJobs) {
            if (PROCESSING_COMPLETE_STATUSES.contains(job.Status__c) && job.Application__c != null) {
                validJobs.add(job);
            }
        }
        return validJobs;
    }
    
    private Set<Id> getApplicationIds(List<AI_Server_Job__c> jobs) {
        Set<Id> applicationIds = new Set<Id>();
        for (AI_Server_Job__c job : jobs) {
            applicationIds.add(job.Application__c);
        }
        return applicationIds;
    }
    
    private void processVerificationTypeForAllScenarios(Set<Id> applicationIds, String verificationType) {
        String searchKeyword = VERIFICATION_TYPES.get(verificationType);
        Map<Id, List<Application_Verification_Summary__c>> appToAVSMap = 
            getAllVerificationSummariesByType(applicationIds, searchKeyword);
        
        Set<Id> applicationsToProcess = new Set<Id>(applicationIds);
        if (!appToAVSMap.isEmpty()) {
            applicationsToProcess.addAll(appToAVSMap.keySet());
        }
        
        for (Id applicationId : applicationsToProcess) {
            List<Application_Verification_Summary__c> avsRecords = appToAVSMap.get(applicationId);
            if (avsRecords == null) avsRecords = new List<Application_Verification_Summary__c>();
            processApplicationVerificationAllScenarios(applicationId, avsRecords, verificationType);
        }
    }
    
    private Map<Id, List<Application_Verification_Summary__c>> getAllVerificationSummariesByType(
        Set<Id> applicationIds, String searchKeyword) {
        
        Map<Id, List<Application_Verification_Summary__c>> appToAVSMap = 
            new Map<Id, List<Application_Verification_Summary__c>>();
        String likePattern = '%' + searchKeyword + '%';
        List<Application_Verification_Summary__c> avsRecords = [
            SELECT Id, Name, Application__c, Percentage_Confidence__c
            FROM Application_Verification_Summary__c
            WHERE Application__c IN :applicationIds AND Name LIKE :likePattern
        ];
        return groupAVSRecordsByApplication(avsRecords);
    }
    
    private Map<Id, List<Application_Verification_Summary__c>> groupAVSRecordsByApplication(
        List<Application_Verification_Summary__c> avsRecords) {
        Map<Id, List<Application_Verification_Summary__c>> appToAVSMap = 
            new Map<Id, List<Application_Verification_Summary__c>>();
        for (Application_Verification_Summary__c avs : avsRecords) {
            if (!appToAVSMap.containsKey(avs.Application__c)) {
                appToAVSMap.put(avs.Application__c, new List<Application_Verification_Summary__c>());
            }
            appToAVSMap.get(avs.Application__c).add(avs);
        }
        return appToAVSMap;
    }
    
    /**
     * MODIFIED: Main processing method with conditional logic based on verification type.
     */
    private void processApplicationVerificationAllScenarios(Id applicationId, 
                                              List<Application_Verification_Summary__c> avsRecords,
                                              String verificationType) {
        
        List<SObject> recordsToUpdate = new List<SObject>();
        List<Id> avsIds = getAVSIds(avsRecords);

        // Conditional logic to determine which objects to update
        if (verificationType == 'RESUME_ANALYSIS') {
            // For Resumes, only a DCI exists and needs to be updated.
            if (!avsRecords.isEmpty()) {
                updateDocumentChecklistItemsForAllAVS(avsIds, avsRecords, recordsToUpdate);
            }
        } else if (verificationType == 'RECOMMENDER_ANALYSIS' || verificationType == 'DECLARATION_ANALYSIS') {
            // For Recommender and Declaration, only a Task exists and needs to be updated.
            updateTaskStatusForAllScenarios(applicationId, verificationType, avsRecords, recordsToUpdate);
        } else {
            // For all other standard types (Education, Employment, etc.), update both.
            if (!avsRecords.isEmpty()) {
                updateDocumentChecklistItemsForAllAVS(avsIds, avsRecords, recordsToUpdate);
            }
            updateTaskStatusForAllScenarios(applicationId, verificationType, avsRecords, recordsToUpdate);
        }
        
        performDMLOperations(recordsToUpdate, 'processApplicationVerificationAllScenarios');
    }
    
    private List<Id> getAVSIds(List<Application_Verification_Summary__c> avsRecords) {
        List<Id> avsIds = new List<Id>();
        for (Application_Verification_Summary__c avs : avsRecords) avsIds.add(avs.Id);
        return avsIds;
    }
    
    private Boolean areAllRecordsFullyVerified(List<Application_Verification_Summary__c> avsRecords) {
        if (avsRecords.isEmpty()) return false;
        for (Application_Verification_Summary__c avs : avsRecords) {
            if (avs.Percentage_Confidence__c == null || avs.Percentage_Confidence__c < HUNDRED_PERCENT) {
                return false;
            }
        }
        return true;
    }
    
    
    
    /**
     * Enhanced: Added new types to find the correct task.
     * Updated: Added support for "applicant detail" alternative naming for personal details.
     */
    private String getTaskSubjectByVerificationType(String verificationType) {
        Map<String, String> taskSubjectPatterns = new Map<String, String>{
            'EDUCATION' => '%education%',
            'TEST_SCORE' => '%test%',
            'EMPLOYMENT' => '%employment%',
            'PERSONAL_DETAILS' => '%personal detail%',
            'RECOMMENDER_ANALYSIS' => '%recommender%',
            'DECLARATION_ANALYSIS' => '%declaration%'
        };
        return taskSubjectPatterns.get(verificationType);
    }
    
    private void updateTaskStatusForAllScenarios(Id applicationId, 
                                               String verificationType,
                                               List<Application_Verification_Summary__c> avsRecords,
                                               List<SObject> recordsToUpdate) {
        String taskSubject = getTaskSubjectByVerificationType(verificationType);
        Boolean allVerified = areAllRecordsFullyVerified(avsRecords);
        
        List<Task> tasksToUpdate;
        
        // Special handling for PERSONAL_DETAILS to check both "personal details" and "applicant detail"
        if (verificationType == 'PERSONAL_DETAILS') {
            tasksToUpdate = [SELECT Id, Status FROM Task WHERE WhatId = :applicationId AND (Subject LIKE '%personal detail%' OR Subject LIKE '%applicant detail%')];
        } else {
            tasksToUpdate = [SELECT Id, Status FROM Task WHERE WhatId = :applicationId AND Subject LIKE :taskSubject];
        }
        
        for (Task t : tasksToUpdate) {
            if (avsRecords.isEmpty()) t.Status = INCOMPLETED_STATUS;
            else if (allVerified) t.Status = COMPLETED_STATUS;
            else t.Status = INCOMPLETED_STATUS;
            recordsToUpdate.add(t);
        }
    }
    
    private void updateDocumentChecklistItemsForAllAVS(List<Id> avsIds, List<Application_Verification_Summary__c> avsRecords, List<SObject> recordsToUpdate) {
        Map<Id, Decimal> avsToConfidenceMap = createAVSConfidenceMap(avsRecords);
        List<DocumentChecklistItem> checklistItems = [SELECT Id, Status, Application_Verification_Summary__c FROM DocumentChecklistItem WHERE Application_Verification_Summary__c IN :avsIds];
        updateAllChecklistItemsBasedOnConfidence(checklistItems, avsToConfidenceMap, recordsToUpdate);
    }
    
    private Map<Id, Decimal> createAVSConfidenceMap(List<Application_Verification_Summary__c> avsRecords) {
        Map<Id, Decimal> avsToConfidenceMap = new Map<Id, Decimal>();
        for (Application_Verification_Summary__c avs : avsRecords) {
            avsToConfidenceMap.put(avs.Id, avs.Percentage_Confidence__c);
        }
        return avsToConfidenceMap;
    }
    
    /**
     * @description Filters out DocumentChecklistItems that should not be auto-updated based on document type and status.
     * This ensures already-approved documents of specific types (e.g., resumes) are not overwritten by automated processes.
     * Protection applies only when BOTH conditions are met:
     *   1. Document name contains a keyword from IMMUTABLE_DCI_DOCUMENT_NAMES (e.g., 'resume')
     *   2. Current status is in IMMUTABLE_DCI_STATUSES (e.g., 'Accepted')
     * @param checklistItems List of DocumentChecklistItem records to filter
     * @return List<DocumentChecklistItem> Filtered list containing only items eligible for update
     */
    private List<DocumentChecklistItem> filterUpdatableChecklistItems(List<DocumentChecklistItem> checklistItems) {
        List<DocumentChecklistItem> updatableItems = new List<DocumentChecklistItem>();
        for (DocumentChecklistItem item : checklistItems) {
            // Check if this document type + status combination should be protected
            if (isImmutableDocument(item)) {
                continue; // Skip this item - it's protected from updates
            }
            updatableItems.add(item);
        }
        return updatableItems;
    }

    /**
     * @description Determines if a DocumentChecklistItem should be immutable (protected from updates).
     * Returns true only when BOTH conditions are met:
     *   1. Item's name contains a protected document keyword (case-insensitive)
     *   2. Item's status is in the immutable status set
     * @param item DocumentChecklistItem to check
     * @return Boolean True if item should be protected from updates, false otherwise
     */
    private Boolean isImmutableDocument(DocumentChecklistItem item) {
        // Check if status is immutable
        if (!IMMUTABLE_DCI_STATUSES.contains(item.Status)) {
            return false; // Status is not protected - item can be updated
        }

        // Check if document name matches any protected document type
        if (String.isBlank(item.Name)) {
            return false; // No name - cannot match protected document types
        }

        String itemNameLower = item.Name.toLowerCase();
        for (String protectedDocName : IMMUTABLE_DCI_DOCUMENT_NAMES) {
            if (itemNameLower.contains(protectedDocName.toLowerCase())) {
                return true; // This is a protected document type with immutable status
            }
        }

        return false; // Document type is not protected - item can be updated
    }

    private void updateAllChecklistItemsBasedOnConfidence(List<DocumentChecklistItem> checklistItems, Map<Id, Decimal> avsToConfidenceMap, List<SObject> recordsToUpdate) {
        // Apply immutability filter: Remove already-accepted items from update scope
        List<DocumentChecklistItem> updatableItems = filterUpdatableChecklistItems(checklistItems);

        for (DocumentChecklistItem item : updatableItems) {
            Decimal confidence = avsToConfidenceMap.get(item.Application_Verification_Summary__c);
            if (confidence != null && confidence >= HUNDRED_PERCENT) item.Status = APPROVED_STATUS;
            else item.Status = PENDING_STATUS;
            recordsToUpdate.add(item);
        }
    }
    
    private Boolean isConfidenceFullyVerified(Decimal confidence) {
        return confidence != null && confidence >= HUNDRED_PERCENT;
    }
    
    private void performDMLOperations(List<SObject> recordsToUpdate, String context) {
        if (!recordsToUpdate.isEmpty()) {
            try {
                List<SObject> validRecordsToUpdate = new List<SObject>();
                for (SObject record : recordsToUpdate) {
                    if (record.Id != null) validRecordsToUpdate.add(record);
                    else System.debug('WARNING: Attempted to process record without ID - skipping: ' + record);
                }
                if (!validRecordsToUpdate.isEmpty()) update validRecordsToUpdate;
            } catch (DMLException e) {
                handleException(context + ' - DML Error', e);
            }
        }
    }
    
    private void handleException(String context, Exception e) {
        System.debug('Error in ' + context + ': ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
    }
}
