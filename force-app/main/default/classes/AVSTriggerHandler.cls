/**
 * Handler class for Application_Verification_Summary__c trigger
 * @description Processes template updates - templates first populate on AVS, then flow to related records
 * @author Nitesh Sinwaer
 */
public class AVSTriggerHandler {
    
    // Constants for Issue Categories
    private static final String ISSUE_CATEGORY_DOCUMENT = 'Document';
    private static final String ISSUE_CATEGORY_DETAILS = 'Details';
    private static final String ISSUE_CATEGORY_BOTH = 'Both';

    /**
     * @description Defines which DocumentChecklistItem document types should have immutable status protection.
     * This prevents overwriting manually approved records for specific document categories during rejection flows.
     * Current scope: Resume documents only.
     * Future: Add other document types as needed (e.g., 'Proof of Identity', 'Marksheet').
     */
    private static final Set<String> IMMUTABLE_DCI_DOCUMENT_NAMES = new Set<String>{
        'resume' // Case-insensitive matching via .toLowerCase()
        // Add more document name keywords here in future (e.g., 'identity', 'marksheet')
    };

    /**
     * @description Defines which statuses should be protected from updates for configured document types.
     * Use case: Once a resume is marked as 'Accepted', it should not be changed to 'Rejected' by AVS updates.
     */
    private static final Set<String> IMMUTABLE_DCI_STATUSES = new Set<String>{
        'Accepted'
        // Add more statuses here if needed (e.g., 'Manually Reviewed', 'Locked')
    };
    
    // Constants for AVS Name patterns
    private static final String PERSONAL_DETAIL_ANALYSIS = 'Personal Detail Analysis';
    private static final String EMPLOYMENT_ANALYSIS = 'Employment Analysis (1)';
    private static final String RECOMMENDER_DETAILS = 'Recommender Details Analysis';
    private static final String DECLARATION_ANALYSIS = 'Declaration Analysis';
    private static final String RESUME_DETAIL_ANALYSIS = 'Resume Detail Analysis';
    private static final String EDUCATION_KEYWORD = 'Education';
    private static final String TEST_KEYWORD = 'Test';
    
    // Education Analysis patterns - easily extensible
    private static final List<String> EDUCATION_ANALYSIS_PATTERNS = new List<String>{
        'Education Analysis (XII)',
        'Education Analysis (Bachelors)'
    };
    
    // Test Score Analysis patterns - easily extensible  
    private static final List<String> TEST_SCORE_PATTERNS = new List<String>{
        'Test Score Analysis (GMAT',
        'Test Score Analysis (GRE'
    };
    
    // Education to Document mapping
    private static final Map<String, String> EDUCATION_DOCUMENT_MAPPING = new Map<String, String>{
        'Education Analysis (XII)' => 'XII Marksheet',
        'Education Analysis (Bachelors)' => 'UG Marksheet'
    };
    
    // Test Score to Document mapping
    private static final Map<String, String> TEST_DOCUMENT_MAPPING = new Map<String, String>{
        'Test Score Analysis (GMAT' => 'GMAT Score Card',
        'Test Score Analysis (GRE' => 'GRE Score Card'
    };
    
    // Document Checklist Item Name mappings
    private static final Map<String, String> DOCUMENT_NAME_MAPPING = new Map<String, String>{
        PERSONAL_DETAIL_ANALYSIS => 'Proof of Identity',
        EMPLOYMENT_ANALYSIS => 'Proof of income for self',
        RESUME_DETAIL_ANALYSIS => 'Resume'
    };
    
    // Task Subject mappings
    private static final Map<String, String> TASK_SUBJECT_MAPPING = new Map<String, String>{
        PERSONAL_DETAIL_ANALYSIS => 'Personal Details',
        EMPLOYMENT_ANALYSIS => 'Employment Details',
        RECOMMENDER_DETAILS => 'Recommender Details',
        DECLARATION_ANALYSIS => 'Declaration'
    };
    
    // Education Task Subject mapping
    private static final Map<String, String> EDUCATION_TASK_MAPPING = new Map<String, String>();
    
    // Test Score Task Subject mapping  
    private static final Map<String, String> TEST_TASK_MAPPING = new Map<String, String>();
    
    // Static block to initialize dynamic mappings
    static {
        // Initialize Education Task mappings
        for (String educationPattern : EDUCATION_ANALYSIS_PATTERNS) {
            EDUCATION_TASK_MAPPING.put(educationPattern, 'Education Details');
        }
        
        // Initialize Test Score Task mappings
        for (String testPattern : TEST_SCORE_PATTERNS) {
            TEST_TASK_MAPPING.put(testPattern, 'Test Score');
        }
    }
    
    // Alternative Task Subject mappings
    private static final Map<String, String> ALTERNATIVE_TASK_SUBJECT_MAPPING = new Map<String, String>{
        PERSONAL_DETAIL_ANALYSIS => 'Applicant Details'
    };
    
    /**
     * Handler method for before insert events - populate templates on AVS creation
     * @param newList List of new AVS records
     */
    public static void handleBeforeInsert(List<Application_Verification_Summary__c> newList) {
        try {
            populateTemplatesOnAVS(newList);
        } catch (Exception e) {
            System.debug('Error in handleBeforeInsert: ' + e.getMessage());
            throw new ApplicationVerificationSummaryException('Error populating templates on AVS creation: ' + e.getMessage());
        }
    }
    
    /**
     * Main handler method for after update events
     * @param newList List of new AVS records
     * @param oldMap Map of old AVS records
     */
    public static void handleAfterUpdate(List<Application_Verification_Summary__c> newList,
                                       Map<Id, Application_Verification_Summary__c> oldMap) {
        
        List<Application_Verification_Summary__c> changedRecords = new List<Application_Verification_Summary__c>();
        
        try {
            // Filter records where Issue_Category__c has changed
            for (Application_Verification_Summary__c newRecord : newList) {
                Application_Verification_Summary__c oldRecord = oldMap.get(newRecord.Id);
                
                if (oldRecord != null &&
                    newRecord.Issue_Category__c != oldRecord.Issue_Category__c &&
                    newRecord.Issue_Category__c != null) {
                    changedRecords.add(newRecord);
                }
            }
            
            if (!changedRecords.isEmpty()) {
                processTemplateUpdation(changedRecords);
            }
            
        } catch (Exception e) {
            System.debug('Error in handleAfterUpdate: ' + e.getMessage());
            throw new ApplicationVerificationSummaryException('Error processing AVS updates: ' + e.getMessage());
        }
    }
    
    /**
     * Populate templates on AVS records at creation time (before insert)
     * @param avsRecords List of newly created AVS records
     */
    private static void populateTemplatesOnAVS(List<Application_Verification_Summary__c> avsRecords) {
        
        try {
            // Collect AVS names for metadata lookup
            Set<String> avsNames = new Set<String>();
            Set<String> educationTestNames = new Set<String>();
            
            for (Application_Verification_Summary__c avs : avsRecords) {
                if (String.isNotBlank(avs.Name)) {
                    avsNames.add(avs.Name);
                    
                    // Check for Education and Test related names
                    if (avs.Name.startsWith(EDUCATION_KEYWORD) || avs.Name.startsWith(TEST_KEYWORD)) {
                        educationTestNames.add(avs.Name);
                    }
                }
            }
            
            if (avsNames.isEmpty()) {
                return;
            }
            
            // Fetch metadata records
            Map<String, Document_Verification_Issue__mdt> documentMetadataMap = getDocumentMetadata(avsNames, educationTestNames);
            Map<String, Detail_Verification_Issue__mdt> detailMetadataMap = getDetailMetadata(avsNames, educationTestNames);
            
            // Populate both templates on AVS records (no DML needed in before insert)
            for (Application_Verification_Summary__c avs : avsRecords) {
                
                // Set Document Template
                Document_Verification_Issue__mdt docMetadata = documentMetadataMap.get(avs.Name);
                if (docMetadata != null && String.isNotBlank(docMetadata.Template_Body__c)) {
                    avs.Document_Template_Comments__c = docMetadata.Template_Body__c;
                }
                
                // Set Detail Template  
                Detail_Verification_Issue__mdt detailMetadata = detailMetadataMap.get(avs.Name);
                if (detailMetadata != null && String.isNotBlank(detailMetadata.Template_Body__c)) {
                    avs.Detail_Template_Comments__c = detailMetadata.Template_Body__c;
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in populateTemplatesOnAVS: ' + e.getMessage());
            throw new ApplicationVerificationSummaryException('Error populating templates on AVS: ' + e.getMessage());
        }
    }
    
    /**
     * Process template updates for changed AVS records - now uses template from AVS record
     * @param avsRecords List of AVS records with changed Issue_Category__c
     */
    private static void processTemplateUpdation(List<Application_Verification_Summary__c> avsRecords) {
        
        try {
            // Collect Application IDs
            Set<Id> applicationIds = new Set<Id>();
            
            for (Application_Verification_Summary__c avs : avsRecords) {
                if (avs.Application__c != null) {
                    applicationIds.add(avs.Application__c);
                }
            }
            
            if (applicationIds.isEmpty()) {
                return;
            }
            
            // Fetch existing DocumentChecklistItem and Task records
            Map<String, List<DocumentChecklistItem>> documentChecklistMap = getDocumentChecklistItems(applicationIds);
            Map<String, List<Task>> taskMap = getTasks(applicationIds);
            
            // Process each AVS record
            List<DocumentChecklistItem> documentsToUpdate = new List<DocumentChecklistItem>();
            List<Task> tasksToUpdate = new List<Task>();
            
            for (Application_Verification_Summary__c avs : avsRecords) {
                processIndividualAVS(avs, documentChecklistMap, taskMap, documentsToUpdate, tasksToUpdate);
            }
            
            // Update records
            updateRecords(documentsToUpdate, tasksToUpdate);
            
        } catch (Exception e) {
            System.debug('Error in processTemplateUpdation: ' + e.getMessage());
            throw new ApplicationVerificationSummaryException('Error processing template updates: ' + e.getMessage());
        }
    }
    
    /**
     * Process individual AVS record - now uses appropriate template from AVS record
     */
    private static void processIndividualAVS(Application_Verification_Summary__c avs,
                                           Map<String, List<DocumentChecklistItem>> documentChecklistMap,
                                           Map<String, List<Task>> taskMap,
                                           List<DocumentChecklistItem> documentsToUpdate,
                                           List<Task> tasksToUpdate) {
        
        String issueCategory = avs.Issue_Category__c;
        
        // Process Document category
        if (issueCategory == ISSUE_CATEGORY_DOCUMENT || issueCategory == ISSUE_CATEGORY_BOTH) {
            if (String.isNotBlank(avs.Document_Template_Comments__c)) {
                processDocumentCategory(avs, documentChecklistMap, documentsToUpdate);
            }
        }
        
        // Process Details category
        if (issueCategory == ISSUE_CATEGORY_DETAILS || issueCategory == ISSUE_CATEGORY_BOTH) {
            if (String.isNotBlank(avs.Detail_Template_Comments__c)) {
                processDetailsCategory(avs, taskMap, tasksToUpdate);
            }
        }
    }
    
    /**
     * Process Document category updates - now uses document template from AVS record
     */
    private static void processDocumentCategory(Application_Verification_Summary__c avs,
                                              Map<String, List<DocumentChecklistItem>> documentChecklistMap,
                                              List<DocumentChecklistItem> documentsToUpdate) {
        
        String documentName = getDocumentName(avs.Name);
        if (String.isBlank(documentName)) {
            return; // Skip if no document name mapping found
        }
        
        String applicationKey = String.valueOf(avs.Application__c);
        List<DocumentChecklistItem> documentItems = documentChecklistMap.get(applicationKey);
        
        if (documentItems == null || documentItems.isEmpty()) {
            return;
        }
        
        // Find matching document checklist items and use document template from AVS
        for (DocumentChecklistItem item : documentItems) {
            if (item.Name != null && item.Name.contains(documentName)) {
                // Skip update if this is a protected document type with immutable status (e.g., resume with Status='Accepted')
                if (isImmutableDocument(item)) {
                    continue; // Preserve immutable status - no changes allowed
                }
                item.randa__Rejection_Comment__c = avs.Document_Template_Comments__c;
                item.Status = 'Rejected';
                documentsToUpdate.add(item);
            }
        }
    }
    
    /**
     * Process Details category updates - now uses detail template from AVS record
     */
    private static void processDetailsCategory(Application_Verification_Summary__c avs,
                                             Map<String, List<Task>> taskMap,
                                             List<Task> tasksToUpdate) {
        
        String taskSubject = getTaskSubject(avs.Name);
        if (String.isBlank(taskSubject)) {
            return; // Skip if no task subject mapping found
        }
        
        String applicationKey = String.valueOf(avs.Application__c);
        List<Task> tasks = taskMap.get(applicationKey);
        
        if (tasks == null || tasks.isEmpty()) {
            return;
        }
        
        // Find matching tasks and use detail template from AVS
        for (Task task : tasks) {
            if (task.Subject != null &&
                (task.Subject.contains(taskSubject) ||
                 (ALTERNATIVE_TASK_SUBJECT_MAPPING.containsKey(avs.Name) &&
                  task.Subject.contains(ALTERNATIVE_TASK_SUBJECT_MAPPING.get(avs.Name))))) {
                
                task.Description = avs.Detail_Template_Comments__c;
                task.Status = 'Need Input';
                tasksToUpdate.add(task);
            }
        }
    }
    
    /**
     * FIXED: Get document metadata records with improved specific matching
     */
    public static Map<String, Document_Verification_Issue__mdt> getDocumentMetadata(Set<String> avsNames, Set<String> educationTestNames) {
        Map<String, Document_Verification_Issue__mdt> metadataMap = new Map<String, Document_Verification_Issue__mdt>();
        
        try {
            // Query for exact matches first (highest priority)
            List<Document_Verification_Issue__mdt> exactMatches = [
                SELECT Label, Template_Body__c
                FROM Document_Verification_Issue__mdt
                WHERE Label IN :avsNames
            ];
            
            for (Document_Verification_Issue__mdt metadata : exactMatches) {
                metadataMap.put(metadata.Label, metadata);
            }
            
            // Query for Education and Test related records only for those not found
            if (!educationTestNames.isEmpty()) {
                List<Document_Verification_Issue__mdt> educationTestMatches = [
                    SELECT Label, Template_Body__c
                    FROM Document_Verification_Issue__mdt
                    WHERE Label LIKE '%Education%' OR Label LIKE '%Test%'
                ];
                
                // FIXED: AVS-centric approach with specific matching
                for (String avsName : educationTestNames) {
                    // Skip if exact match already found
                    if (metadataMap.containsKey(avsName)) {
                        continue;
                    }
                    
                    Document_Verification_Issue__mdt bestMatch = null;
                    
                    // Find the most specific match first
                    for (Document_Verification_Issue__mdt metadata : educationTestMatches) {
                        if (isSpecificMatch(avsName, metadata.Label)) {
                            bestMatch = metadata;
                            break; // Found specific match, stop looking
                        }
                    }
                    
                    // If no specific match found, try partial match as fallback
                    if (bestMatch == null) {
                        for (Document_Verification_Issue__mdt metadata : educationTestMatches) {
                            if (isPartialMatch(avsName, metadata.Label)) {
                                bestMatch = metadata;
                                break;
                            }
                        }
                    }
                    
                    if (bestMatch != null) {
                        metadataMap.put(avsName, bestMatch);
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error querying Document_Verification_Issue__mdt: ' + e.getMessage());
        }
        
        return metadataMap;
    }
    
    /**
     * FIXED: Get detail metadata records with improved specific matching
     */
    public static Map<String, Detail_Verification_Issue__mdt> getDetailMetadata(Set<String> avsNames, Set<String> educationTestNames) {
        Map<String, Detail_Verification_Issue__mdt> metadataMap = new Map<String, Detail_Verification_Issue__mdt>();
        
        try {
            // Query for exact matches first (highest priority)
            List<Detail_Verification_Issue__mdt> exactMatches = [
                SELECT Label, Template_Body__c
                FROM Detail_Verification_Issue__mdt
                WHERE Label IN :avsNames
            ];
            
            for (Detail_Verification_Issue__mdt metadata : exactMatches) {
                metadataMap.put(metadata.Label, metadata);
            }
            
            // Query for Education and Test related records only for those not found
            if (!educationTestNames.isEmpty()) {
                List<Detail_Verification_Issue__mdt> educationTestMatches = [
                    SELECT Label, Template_Body__c
                    FROM Detail_Verification_Issue__mdt
                    WHERE Label LIKE '%Education%' OR Label LIKE '%Test%'
                ];
                
                // FIXED: AVS-centric approach with specific matching
                for (String avsName : educationTestNames) {
                    // Skip if exact match already found
                    if (metadataMap.containsKey(avsName)) {
                        continue;
                    }
                    
                    Detail_Verification_Issue__mdt bestMatch = null;
                    
                    // Find the most specific match first
                    for (Detail_Verification_Issue__mdt metadata : educationTestMatches) {
                        if (isSpecificMatch(avsName, metadata.Label)) {
                            bestMatch = metadata;
                            break; // Found specific match, stop looking
                        }
                    }
                    
                    // If no specific match found, try partial match as fallback
                    if (bestMatch == null) {
                        for (Detail_Verification_Issue__mdt metadata : educationTestMatches) {
                            if (isPartialMatch(avsName, metadata.Label)) {
                                bestMatch = metadata;
                                break;
                            }
                        }
                    }
                    
                    if (bestMatch != null) {
                        metadataMap.put(avsName, bestMatch);
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error querying Detail_Verification_Issue__mdt: ' + e.getMessage());
        }
        
        return metadataMap;
    }
    
    /**
     * NEW: Helper method for specific matching
     * Checks for exact or very close matches with specific patterns
     */
    private static Boolean isSpecificMatch(String avsName, String metadataLabel) {
        // Exact match (highest priority)
        if (avsName.equals(metadataLabel)) {
            return true;
        }
        
        // Education specific matches
        if (avsName.startsWith(EDUCATION_KEYWORD) && metadataLabel.startsWith(EDUCATION_KEYWORD)) {
            // Check for specific education level matches
            if (avsName.contains('(XII)') && metadataLabel.contains('(XII)')) {
                return true;
            }
            if (avsName.contains('(Bachelors)') && metadataLabel.contains('(Bachelors)')) {
                return true;
            }
            if (avsName.contains('(Masters)') && metadataLabel.contains('(Masters)')) {
                return true;
            }
            if (avsName.contains('(X)') && metadataLabel.contains('(X)') && !avsName.contains('(XII)') && !metadataLabel.contains('(XII)')) {
                return true;
            }
        }
        
        // Test specific matches
        if (avsName.startsWith(TEST_KEYWORD) && metadataLabel.startsWith(TEST_KEYWORD)) {
            // Check for specific test type matches
            if (avsName.contains('(GMAT') && metadataLabel.contains('(GMAT')) {
                return true;
            }
            if (avsName.contains('(GRE') && metadataLabel.contains('(GRE')) {
                return true;
            }
            if (avsName.contains('(TOEFL') && metadataLabel.contains('(TOEFL')) {
                return true;
            }
            if (avsName.contains('(IELTS') && metadataLabel.contains('(IELTS')) {
                return true;
            }
            if (avsName.contains('(SAT') && metadataLabel.contains('(SAT')) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * NEW: Helper method for partial matching (fallback only)
     * Only use when specific match not found - provides generic fallback
     */
    private static Boolean isPartialMatch(String avsName, String metadataLabel) {
        // Generic education match (fallback only)
        if (avsName.startsWith(EDUCATION_KEYWORD) && metadataLabel.contains(EDUCATION_KEYWORD) && 
            !metadataLabel.contains('(') && !metadataLabel.contains(')')) {
            return true;
        }
        
        // Generic test match (fallback only)
        if (avsName.startsWith(TEST_KEYWORD) && metadataLabel.contains(TEST_KEYWORD) && 
            !metadataLabel.contains('(') && !metadataLabel.contains(')')) {
            return true;
        }
        
        return false;
    }
    
    /**
     * Get DocumentChecklistItem records
     */
    private static Map<String, List<DocumentChecklistItem>> getDocumentChecklistItems(Set<Id> applicationIds) {
        Map<String, List<DocumentChecklistItem>> checklistMap = new Map<String, List<DocumentChecklistItem>>();
        
        try {
            List<DocumentChecklistItem> items = [
                SELECT Id, Name, ParentRecordId, randa__Rejection_Comment__c, Status
                FROM DocumentChecklistItem
                WHERE ParentRecordId IN :applicationIds
            ];
            
            for (DocumentChecklistItem item : items) {
                String key = String.valueOf(item.ParentRecordId);
                if (!checklistMap.containsKey(key)) {
                    checklistMap.put(key, new List<DocumentChecklistItem>());
                }
                checklistMap.get(key).add(item);
            }
            
        } catch (Exception e) {
            System.debug('Error querying DocumentChecklistItem: ' + e.getMessage());
        }
        
        return checklistMap;
    }
    
    /**
     * Get Task records
     */
    private static Map<String, List<Task>> getTasks(Set<Id> applicationIds) {
        Map<String, List<Task>> taskMap = new Map<String, List<Task>>();
        
        try {
            List<Task> tasks = [
                SELECT Id, Subject, WhatId, Description, Status
                FROM Task
                WHERE WhatId IN :applicationIds
            ];
            
            for (Task task : tasks) {
                String key = String.valueOf(task.WhatId);
                if (!taskMap.containsKey(key)) {
                    taskMap.put(key, new List<Task>());
                }
                taskMap.get(key).add(task);
            }
            
        } catch (Exception e) {
            System.debug('Error querying Task: ' + e.getMessage());
        }
        
        return taskMap;
    }
    
    /**
     * @description Determines if a DocumentChecklistItem should be immutable (protected from updates).
     * Returns true only when BOTH conditions are met:
     *   1. Item's name contains a protected document keyword (case-insensitive)
     *   2. Item's status is in the immutable status set
     * @param item DocumentChecklistItem to check
     * @return Boolean True if item should be protected from updates, false otherwise
     */
    private static Boolean isImmutableDocument(DocumentChecklistItem item) {
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

    /**
     * Get document name based on AVS name
     */
    private static String getDocumentName(String avsName) {
        if (String.isBlank(avsName)) {
            return null;
        }
        
        // Check standard mappings first
        for (String key : DOCUMENT_NAME_MAPPING.keySet()) {
            if (avsName.contains(key)) {
                return DOCUMENT_NAME_MAPPING.get(key);
            }
        }
        
        // Check education mappings
        for (String educationKey : EDUCATION_DOCUMENT_MAPPING.keySet()) {
            if (avsName.contains(educationKey)) {
                return EDUCATION_DOCUMENT_MAPPING.get(educationKey);
            }
        }
        
        // Check test score mappings
        for (String testKey : TEST_DOCUMENT_MAPPING.keySet()) {
            if (avsName.contains(testKey)) {
                return TEST_DOCUMENT_MAPPING.get(testKey);
            }
        }
        
        return null;
    }
    
    /**
     * Get task subject based on AVS name
     */
    private static String getTaskSubject(String avsName) {
        if (String.isBlank(avsName)) {
            return null;
        }
        
        // Check standard mappings first
        for (String key : TASK_SUBJECT_MAPPING.keySet()) {
            if (avsName.contains(key)) {
                return TASK_SUBJECT_MAPPING.get(key);
            }
        }
        
        // Check education mappings
        for (String educationKey : EDUCATION_TASK_MAPPING.keySet()) {
            if (avsName.contains(educationKey)) {
                return EDUCATION_TASK_MAPPING.get(educationKey);
            }
        }
        
        // Check test score mappings
        for (String testKey : TEST_TASK_MAPPING.keySet()) {
            if (avsName.contains(testKey)) {
                return TEST_TASK_MAPPING.get(testKey);
            }
        }
        
        return null;
    }
    
    /**
     * Update DocumentChecklistItem and Task records
     */
    private static void updateRecords(List<DocumentChecklistItem> documentsToUpdate, List<Task> tasksToUpdate) {
        
        try {
            // Update DocumentChecklistItem records
            if (!documentsToUpdate.isEmpty()) {
                Database.SaveResult[] docResults = Database.update(documentsToUpdate, false);
                handleSaveResults(docResults, 'DocumentChecklistItem');
            }
            
            // Update Task records
            if (!tasksToUpdate.isEmpty()) {
                Database.SaveResult[] taskResults = Database.update(tasksToUpdate, false);
                handleSaveResults(taskResults, 'Task');
            }
            
        } catch (Exception e) {
            System.debug('Error updating records: ' + e.getMessage());
            throw new ApplicationVerificationSummaryException('Error updating records: ' + e.getMessage());
        }
    }
    
    /**
     * Handle save results and log errors
     */
    private static void handleSaveResults(Database.SaveResult[] results, String objectType) {
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {
                    System.debug('Error updating ' + objectType + ': ' + error.getMessage());
                }
            }
        }
    }
    
    /**
     * Custom exception class
     */
    public class ApplicationVerificationSummaryException extends Exception {}
}